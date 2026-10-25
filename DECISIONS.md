# Decisions

Settled choices for the v2 playground, with the reason where it is not obvious. Treat them as fixed. To
change one, ask the maintainers first, then update this file in the same change.

## Scope

- **A total refresh, not a migration.** Nothing stays compatible with `jenkins-vars.yml`, `readme-vars.yml`
  or the Jenkins-generated file set. What carries over: the s6 base images, the mods model, the content of
  readme-vars, and the test harness ideas.
- **GitHub only** for the proof of concept: Actions, GHCR, Releases, Pages. No registry mirroring, no pushes to
  several registries, no Scarf.
- **A curated set of images,** not a mirror of the whole fleet.
- **riscv64 is out of scope.**

## Image repos and the pipeline

- **One manifest per branch**, `image.yml`, validated by a JSON Schema. Everything else in an image repo is
  generated from it.
- **Templating commits happen once, on the live branch.** PRs are only checked. A push made with
  `GITHUB_TOKEN` never triggers workflows, so the package check dispatches the release build itself. Bot
  commits use `[skip ci]`.
- **`package_versions.txt` stays in the repos,** and the hub also keeps structured SBOMs with a stronger
  package diff.
- **Namespaces.**
  - PR builds are full builds pushed to `ghcr.io/linuxserver-playground/untrusted-pr/<name>` and deleted
    when the PR closes.
- **Pull request code never runs where a secret is.** The Build of a PR runs the PR's code with a read-only
  token and posts nothing. The trusted half, each image repo's generated `pr-report.yml` (workflow_run and
  pull_request_target, from the base branch), only reads the Build run's artifacts as data: it posts the one
  report comment (tests per arch, screenshots as comment attachments with `ATTACHMENTS_TOKEN`, package
  changes, logs), publishes a fork's image only after a maintainer adds `safe-to-publish` (removed on every new
  push), and deletes the PR's images on close. Fork workflows need approval for all external contributors.
- **Generated-file drift only warns in PR and branch builds;** the live build re-renders after merge. A PR that
  edits a generated file still fails.
  - Branch builds go to `dev/` and are kept 30 days.
  - Arch builds are staged in `build/` and promoted by publish.
- **Runners.** Free disk space first, then build, test and scan per arch on native runners. No cross-arch
  pulls and no duplicate SBOMs. 20 concurrent jobs are acceptable.
- **SBOM.** One syft scan in ci, trimmed to packages. Our own lean SPDX attestation is attached at publish,
  still readable by third-party tools. BuildKit's `--sbom` is off because it produced attestations over
  80 MB on webtop.
- **File trees** come from `dumper`, a static Rust walker mounted into ci (not embedded in images). The tree
  shows files only: no per-file layer numbers and no package ownership.
- **Screenshots.** ci waits at least 30 s on amd64 and 90 s on arm64 for selkies, kasmvnc and rdesktop
  bases.

## Control plane

- **A central scheduler** replaces every per-repo cron: hourly upstream checks, hourly release checks, and
  weekly package checks.
- **Control is a small always-on server** (n97 for the playground) and stays light. It handles webhooks,
  live status, the queue, scheduler decisions, badges, member actions and notifications. Everything derived
  from releases is rendered by the hub on Pages or by the site.
- **Control holds every notification and GitHub App credential.** Image repos never hold a hub token or a
  Discord webhook.
- **A release's Discord message is held until its site page is live** ("passed, publishing"), so it never
  links a 404. Past 30 minutes control posts where it is stuck (hub or site); it stops watching after 24 h.
- **Fleet auth on the site** uses control's session cookie (`SameSite=None; Secure`, CORS with credentials,
  a CSRF header from `/api/me`). Production would share one registrable domain. In the playground, test member
  actions in Chromium.
- **Member sign-in** is a classic OAuth App, so GitHub shows no "act on your behalf" consent. Actions use the
  App installation token.

## Hub and site

- **The site is the single pane of glass.** Nobody should need to leave it except for issues, PRs and raw run
  logs. Image pages carry the complete documentation rendered from the manifest. Anything only a README or the
  hub says is a gap in the site. The separate docs site is archived; non-image docs and the blog live in the
  site as content collections. The fleet dashboard lives in the site too.
- **Heavy data** (file trees) stays on GitHub Releases. Release assets have no CORS headers, so the site fetches
  them through control's CORS gateway, with a loading state.
- **Vulnerabilities** are shown on build pages, with backport-aware framing, for users who look for them; they
  are never a headline and not on image pages. The hub runs grype on new builds in the run that ingests them.
- **Every hub run sweeps for pending releases.** A dispatch's payload is only a hint: GitHub drops all but one
  pending run per concurrency group, so each run (dispatch or push) ingests every release `data/` lacks.
- **Stores.** The hub generates Unraid, Portainer, CasaOS, Umbrel, Runtipi, Cosmos and Arcane templates, with
  the store id prefix `lsio`. Unraid, Umbrel and Runtipi read a git repo, so the hub pushes them to
  `unraid-store`, `umbrel-store` and `runtipi-store`. The site's stores page lists only these stores;
  Kubernetes, quadlets and SWAG confs are per-image files on image pages. TrueNAS needs no shim: it has no third-party catalog since 24.10. The docs cover
  Kubernetes and LXC on Proxmox, and the hub generates k8s manifests.
- **SWAG proxy confs** are generated from each image's `proxy` block by the hub, and SWAG pulls the generated
  repo. Non-LinuxServer apps keep their hand-maintained confs.

## Working in the org

- Repos, commits, branches and tags in `linuxserver-playground` need no sign-off. The real `linuxserver` org
  is read-only.
- Commits carry no trailers, AI co-author lines included (CONVENTIONS §8).
- Coordination between contributors is best effort.
