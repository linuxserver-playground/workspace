#!/usr/bin/env bash
# Clones every repository of linuxserver-playground into repos/ (or fast-forwards the ones already there), so an
# agent started at the root of this workspace can read and change all of them. Safe to re-run.
#
#   ./bootstrap.sh              clone or update every repo
#   ./bootstrap.sh --setup      also install each repo's dev environment (venvs, npm, cargo); slow
#   ./bootstrap.sh --reference  also clone the read-only linuxserver/* originals the playground replaces
#
# REPOS_DIR and REFERENCE_DIR override the targets (e.g. REPOS_DIR=.. when the clones already sit beside this one).
set -euo pipefail

ORG=linuxserver-playground
REFERENCE=(docker-ci docker-jenkins-builder docker-mods templates docker-documentation reverse-proxy-confs)
here=$(cd "$(dirname "$0")" && pwd)
repos_dir=${REPOS_DIR:-$here/repos}
reference_dir=${REFERENCE_DIR:-$here/reference}
setup=false
reference=false
for arg in "$@"; do
  case "$arg" in
    --setup) setup=true ;;
    --reference) reference=true ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

for tool in gh git; do
  command -v "$tool" >/dev/null || { echo "$tool is required" >&2; exit 1; }
done
gh auth status >/dev/null 2>&1 || { echo "run 'gh auth login' first" >&2; exit 1; }

# Clone owner/name into dir, or fast-forward it when it is clean and on its default branch.
sync() {
  local slug=$1 dir=$2
  if [[ ! -d "$dir/.git" ]]; then
    gh repo clone "$slug" "$dir" -- --quiet
    echo "cloned   $slug"
    return
  fi
  local default current
  default=$(git -C "$dir" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  current=$(git -C "$dir" branch --show-current)
  if [[ -n "$(git -C "$dir" status --porcelain)" || "$current" != "${default:-$current}" ]]; then
    git -C "$dir" fetch --quiet
    echo "fetched  $slug (on $current with local changes or off the default branch; not merged)"
  elif git -C "$dir" pull --quiet --ff-only; then
    echo "updated  $slug"
  else
    echo "diverged $slug (left as is)"
  fi
}

mkdir -p "$repos_dir"
gh repo list "$ORG" --limit 500 --no-archived --json name --jq '.[].name' | sort | while read -r name; do
  # .github would be a hidden directory; every other repo keeps its own name
  dir=$repos_dir/$name
  [[ "$name" == ".github" ]] && dir=$repos_dir/dot-github
  sync "$ORG/$name" "$dir"
done

# Generated data is not on main: the hub's data/ and the site's snapshots are the one commit of each repo's data
# branch. Lay them into the clones, so a build works straight away. Both only replace generated files.
[[ -x "$repos_dir/hub/scripts/data.sh" ]] && { "$repos_dir/hub/scripts/data.sh" || echo "hub data/ not refreshed" >&2; }
[[ -x "$repos_dir/site/scripts/snapshot.sh" ]] && { "$repos_dir/site/scripts/snapshot.sh" restore || echo "site snapshots not restored" >&2; }

if $reference; then
  mkdir -p "$reference_dir"
  for name in "${REFERENCE[@]}"; do
    sync "linuxserver/$name" "$reference_dir/$name"
  done
fi

if $setup; then
  python=$(command -v python3.13 || command -v python3)
  for name in builder workflows ci hub control; do
    [[ -f "$repos_dir/$name/pyproject.toml" ]] || continue
    echo "setup    $name (venv)"
    (cd "$repos_dir/$name" && "$python" -m venv .venv && .venv/bin/pip install -q -e '.[dev]')
  done
  if command -v npm >/dev/null; then
    echo "setup    site (npm ci)"
    (cd "$repos_dir/site" && npm ci --silent)
  else
    echo "skipped  site: npm not found"
  fi
  if command -v cargo >/dev/null; then
    echo "setup    dumper (cargo build)"
    (cd "$repos_dir/dumper" && cargo build --quiet)
  else
    echo "skipped  dumper: cargo not found"
  fi
fi
