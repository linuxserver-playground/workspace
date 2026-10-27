# Live cutover

Changes needed before the v2 layout moves from `linuxserver-playground` into the real `linuxserver`
organisation. These are things the playground got away without, or does differently on purpose. Settle them
during the cutover, not before.

Add a bullet when you find one. Keep each to a line or two, with a link to where the detail is. Namespace
rewrites in image repos have their own list in [playground-references.md](playground-references.md).

## Organisations and namespaces

- **Swap every playground reference back.** [playground-references.md](playground-references.md) lists them.
- **Org name defaults.** These are hard-coded to `linuxserver-playground` and must be changed:
  - `github_org` in `control/config.py`;
  - `BUILDER_ORG` and the other `builder.manifest.Settings` defaults;
  - the hub's site config;
  - the `linuxserver-playground` deny and allow rules in the harness and workspace `.claude/settings.json`.
- **The builder image's base.** It builds `FROM ghcr.io/linuxserver/baseimage-alpine:3.22`. That is already
  the production name, but it breaks the playground's namespace rule today.
- **The harness.** `./harness` defaults to the playground's org, control and hub URLs (`HARNESS_*`
  overrides). Its guard hook and settings name `linuxserver-playground`. Its roles are member and contributor;
  map them to LinuxServer's tiers (below).
- **Labs.**
  - The playground demo uses `linuxserver-playground-labs`.
  - Production has `linuxserver-labs`, and may split into sub-orgs. Decide the org layout, the proposal
    flow, and what graduating into `linuxserver` means.
- **Image names with `.` or `_`.** Examples: `changedetection.io`, `your_spotify`, `doplarr_rs`. They wait
  on a schema decision (DECISIONS: Scope).

## Hosting and distribution

- **Control.** Move it from n97 to a data-centre server.
- **One domain.** Site and control share one registrable domain, so the session cookie no longer needs
  `SameSite=None` and member actions work in every browser (DECISIONS: Control plane).
- **Other registries, git mirrors and backups.** A control-run phase (workspace #4, #5). lscr.io keeps
  proxying GHCR.
- **Docs URLs.** Point the site, hub and docs URLs baked into generated files (`builder.manifest.Settings`)
  at the production domains.

## Membership, permissions and review

- **Tiers.** LinuxServer has tiered membership: developers, support and others. The playground has two
  roles, member (everyone an owner) and outsider. Map the tiers to GitHub teams.
- **Where the tiers apply:**
  - control's `require_member` and the editor's `can_edit` (both org membership today);
  - the harness's `whoami` roles and guard hook;
  - CODEOWNERS.
- **Branch protection or rulesets** on live branches and infra `main`: a PR is required, Build or Check must
  pass, and no force push. The playground has none. Org-level rulesets need GitHub Team.
- **Automated agentic PR review** (pullfrog or similar). It needs a model API key as an org secret. It must
  not run PR code where that secret is (`workflow_run` or `pull_request_target`, artifacts read as data
  only).

## Contribution pipeline gaps

Each of these works for owners pushing directly, but would trip up real contributors.

- **Builder has no PR checks.** A merge ships `builder:latest` to the whole fleet at once. Add `check.yml`:
  ruff, mypy, pytest, the contracts examples and the golden render.
- **New repo, first PR.** The harness works around this today. The placeholder default branch carries the
  generic generated workflows and LICENSE (`[skip ci]`), and the first PR leaves README and AGENTS.md to the
  live build. As a result, reviewers do not see the rendered README in the PR. To fix that properly, exempt a
  base branch with no `image.yml` from `update_generated.sh check`, and let the first PR carry everything.
- **Local rendering, the successor to jenkins-builder.** `builder:latest` renders only the files a repo
  commits. What it needs:
  - a `hub-preview` tool image, so anyone can see the stores, proxy confs, k8s, quadlet and catalog entry
    an `image.yml` produces without merging (`lsio_hub.preview`, built like `tests/conftest.py`'s ingest);
  - later, a site script that builds one image page from that output;
  - in the builder image: write files as the owner of the mounted repo (no `--user` needed), and add
    `render --out DIR`, so a PR branch can be previewed without committing generated files.
- **Mod PRs.** `mod-build.yml` should validate `mod.yml`, run `render-mod --check` and refuse edits to
  generated files. Mods need a report and cleanup of `untrusted-pr/mods:*-pr-<n>`, which the README promises
  and nothing does. New mods need a member to create the branch.
- **`safe-to-publish`.** The label is only created when the first fork PR arrives. Pre-create it.
- **Contradictory render advice.** CONTRIBUTING, the PR template and the image `AGENTS.md` template say to
  run `builder render`, but a PR that commits its output fails. Document `check --drift warn` for PR
  branches, to match CI.
- **CONTRIBUTING is stale.**
  - It names the `ghcr.io/linuxserver/baseimage-*` base images.
  - It says test reports are on control; they arrive as the PR comment.
  - It leaves `pr-report.yml` out of the generated files list.
  - It links to org Discussions, which are disabled.
- **Stray templates.** Remove the per-repo issue and PR templates in `docker-your_spotify` and
  `docker-doplarr_rs`.
- **Doc drift.**
  - The control README describes the member check wrongly and gives the wrong `HUB_CONSUMERS` default.
  - DECISIONS names a control "CORS gateway" that does not exist.
  - The workspace recipe mentions "contracts models"; there are none.
  - The hub's fixtures README names `mod-list.yml`, but the file is `mods.yml`.
- **Fork approvals.** Fork runs need a maintainer to approve them (`all_external_contributors`). Decide
  whether a contributor tier can approve.
