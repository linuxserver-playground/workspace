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
  - Until Labs exists, the site sends image proposals to issues on `harness` titled `Proposal:`
    (`PROPOSALS_URL` in the site's `src/lib/contribute.ts`, `/docs/contribute/proposing-an-image/` and its "Coming:
    Labs" panel). Repoint all three, and the harness's propose-image playbook, when Labs opens.
- **New mods from outside.** A contributor cannot create a mod branch, so a new mod is an issue and a wait for a
  member (`/docs/contribute/making-a-mod/`). Decide whether a fork PR can propose a new branch (an `incoming`
  branch, or a bot that creates `<target>-<name>` from an approved issue).
- **Image names with `.` or `_`.** Examples: `changedetection.io`, `your_spotify`, `doplarr_rs`. They wait
  on a schema decision (DECISIONS: Scope).

## Version sources and triggers

- **Typed sources replaced 56 `command` sources in the playground** (commit `Read the upstream version with a
  typed source instead of a shell command`, and `Follow the playground's arch base image releases for the
  upstream version` on six branches). Upstream's jenkins-vars still has the commands. Carry the playground's
  `image.yml` over as it is. Each new source printed the same version as the command it replaced on 2026-10-28,
  except two:
  - darktable now leaves out the Arch epoch, so its tags go from `25.6.2-1` to `5.6.2-1`;
  - webtop's `arch-*` branches follow the arch base image's releases instead of a stale kasmvnc tag.
- **Four branches keep `command` sources:**
  - baseimage-arch builds daily from `date`;
  - nextcloud `previous` works out the previous major from the current one;
  - python `ha` reads two of Home Assistant's Dockerfiles;
  - intellij-idea, which is broken (below).
- **intellij-idea is broken on live too.** Arch renamed `intellij-idea-community-edition` to `intellij-idea-oss`.
  The Dockerfile and the version source both need the new name.
- **Control's command sandbox depends on the LinuxServer container.** It needs doas,
  `/usr/local/bin/run-version-command`, and the init script that closes `/run/s6/container_environment`.
  Keep them if control moves off n97 or out of the image (control `AGENTS.md`).
- **Comparing build load with live.** Count GHCR package versions, not Releases: a release's `created_at` is its
  tagged commit's date, and a triggered release tags an old head. The playground's first count after the
  change, 155 releases to live's 119 over 42 hours, was made that way.

## Batch build projects

- **Carry proot-apps' playground workflows over, not upstream's.** They were refactored on 2026-10-29 (commits
  `Build, scan and publish each app in one pass and commit its package list without a second run` and
  `Rebuild only the base images the apps being built use`; proot-apps `AGENTS.md` has the detail). This is what
  upstream does:
  - its nightly check builds every app on amd64 only to scan it, commits `package_versions.txt`, then dispatches
    `build-on-commit`, which rebuilds every base image and builds the changed apps again for both arches;
  - a push build never updates `package_versions.txt`, so the next night finds the drift and rebuilds the app
    once more.

  The playground instead:
  - builds and scans amd64 once per app in `ci-scripts/build-app.sh`, then pushes every arch, with amd64 from
    the builder's cache, so the image pushed is the image scanned;
  - publishes from the nightly check (mode `check`) only the apps whose packages changed, and dispatches nothing;
    a push or a dispatch (mode `push`) always publishes;
  - commits `package_versions.txt` from both workflows as Package Bot with `GITHUB_TOKEN`, which starts no run,
    and `build-on-commit`'s change detection ignores those files;
  - refreshes all seven base images in the nightly check, while `build-on-commit` rebuilds only the bases its
    apps build `FROM` (all of them for `build_all` or a change under `base-images/` other than one Dockerfile);
  - drops `update-packages.sh`, and grants `build-on-commit` `contents: write` and the package check
    `packages: write`.

  Forks still need no secrets.
- **Measure the proot-apps nights before the cutover.** Before the refactor, a night was the check (126 jobs,
  about 220 runner-minutes) plus a `build changed` run (13 to 32 jobs, 53 to 124 runner-minutes). Compare the
  nights from 2026-10-30 against those numbers, on control's `/api/batch.json` or the runs' jobs.
- **solidcraft is broken on live too.** SolidCraft renamed its desktop file and icon from
  `ai.storyteller.solidcraft` to `io.tangencylabs.solidcraft`, so live's Dockerfile and `install` fail. The
  playground's fix (`Follow SolidCraft's rename of its desktop file and icon to io.tangencylabs`) carries over
  with the workflows.
- **Set `SCHEDULED_BY_CONTROL=true` on the live batch repos** (proot-apps, selkies-layers) when control takes
  over their nightly runs. It is a repository variable, so a git push does not carry it, and until it is set
  their own crons run beside control's dispatches.

## Hosting and distribution

- **Control.** Move it from n97 to a data-centre server.
- **Size control's storage for the new server.** n97's defaults keep a week of webhook deliveries and two daily
  database snapshots (`CONTROL_DELIVERIES_KEEP_DAYS=7`, `CONTROL_SNAPSHOTS_KEEP=2`), because a week of the
  playground's deliveries alone was 2.2 GB. The production server has hundreds of GB, so raise both in its `.env`,
  for example a month or more of deliveries and a week of snapshots. Snapshots live on the same disk, so also copy
  the data dir (snapshots and `github_app.json`) off the host (control `deploy/n97/README.md`).
- **Create the production App without the check events.** The playground App subscribes to Check run and Check
  suite, which nothing reads; control drops them unstored. A new App created from the manifest leaves them out;
  untick them on any App created before 2026-10-29.
- **triage.** Move it with control, as its own compose project beside it (`triage/deploy/`).
- **Scrub the playground host.** Once nothing runs on n97, remove what names it from the public repos: n97,
  `/home/thelamer/...` paths and `ci.thelamer.duckdns.org` in control (`deploy/n97/`, `config.py`, README), in
  triage's `TRIAGE_CONTROL_URL` default, in the site's control URL, and in this workspace's AGENTS.md,
  DECISIONS.md and docs.
- **One domain.** Site and control share one registrable domain, so the session cookie no longer needs
  `SameSite=None` and member actions work in every browser (DECISIONS: Control plane).
- **Other registries, git mirrors and backups.** A control-run phase (workspace #4, #5). lscr.io keeps
  proxying GHCR.
- **Image repos' Pages.** Each `docker-*` repo serves its builds' heavy files from Pages at
  `<org>.github.io/<repo>/` (CONVENTIONS §6, "Repo Pages"; the hub's `config.repo_pages()`). If the org's own
  Pages site gets a custom domain, every project site moves under it and shares a path namespace with whatever
  that domain serves, so give it a data domain (not the website's) or none. Enable Pages on every repo first
  (a maintainer, as in the new-image recipe; control only reports repos without it and never gets
  Administration write), then backfill with a `reason: pages` dispatch per repo before the hub links them.
- **The hub's website URL.** `config.WEBSITE` and `site_build()` in the hub hard-code the playground site; its
  `/builds/<image>/<tag>/` redirect stubs and `links.test_report` follow them.
- **Docs URLs.** Point the site, hub and docs URLs baked into generated files (`builder.manifest.Settings`)
  at the production domains.
- **Wheel index.** Point the `wheel-index.linuxserver.io` CNAME at wheelie's Pages (custom domain on the repo),
  then revert the `Install wheels from the playground wheel index` commits
  ([playground-references.md](playground-references.md#wheelie)) and wheelie's `INDEX_URL` default. The index
  is a public integration, not only ours: the mods' `package-install.v1` (fetched by every base image from
  `linuxserver/docker-mods` `mod-scripts`) adds `-f https://wheel-index.linuxserver.io/alpine-${ALPINE_VER}/`
  or `/ubuntu/` at runtime in users' containers, on whatever Alpine they run, and outside projects (SickChill,
  Calibre-Web-Automated, home-operations/containers, bazarr upstream) use it too. So the live cutover keeps
  every existing page, including old Alpine versions the fleet no longer builds, and every legacy
  `wheels.linuxserver.io` link: keep the S3 bucket serving read-only rather than deleting or trimming
  anything. Only new wheels go to Release assets. The playground's trimmed pages are not a model for this.
  - *Why the new index publishes so little.* The old wheelie dates from when PyPI had almost no musl or
    aarch64 wheels, so building them centrally saved every Alpine and arm image a compile. Since then upstream
    projects have published musllinux and manylinux wheels for both arches themselves, and wheelie went on
    rebuilding what PyPI already had: of the 1,781 legacy entries on the ubuntu page (October 2026), 1,150
    are byte-identical copies of PyPI files, 562 are armhf, about 60 are for Pythons no base ships, and 4 suit
    a current image. The new wheelie builds only what pip would otherwise compile: sdist-only packages
    (bluepy today) and the window after a CPython bump before upstream ships wheels for it. So the newest
    entries on each page will be few, and that is expected.
- **Jenkins External-Triggers.** Control's hourly mod check replaces the `mod-*-external-trigger` jobs for the
  mods with an `upstream` block. Disable those jobs when the mods move, or both build every new version. The
  check reads `ghcr.io/<org>/mods:<branch>-<version>`, the tag the Jenkins jobs looked for on Docker Hub, so
  a mod version Jenkins already built on GHCR counts as built. `code-server-golang`'s three Go lines
  (`upstream.lines`) reproduce upstream's tags but two oddities: release candidates are tagged `-1.28rc1`, not
  also `-1.28rc1.0` (BuildImage.yml padded a one-dot version), and the floating `-X`/`-X.Y` tags get no
  `-<sha>` twins. Nobody should pin either, but the old tags stay on GHCR; do not prune them.
- **Mod names and modmanager.** `docker-mods.v3` sends `linuxserver/*` and `ghcr.io/linuxserver/*` mods
  through lscr.io, so playground mods only work by their full name, `ghcr.io/linuxserver-playground/mods:<branch>`,
  and go straight to ghcr.io. Back in `linuxserver` the short names and lscr routing apply again with no change.
  Modmanager has no mod logic of its own (it runs its base's `/docker-mods` with `MODMANAGER_MODONLY`), so it
  follows whichever mod scripts its base image fetched; swap the `mod-scripts` URL back with the base images
  ([playground-references.md](playground-references.md)) and rebuild it after them. Imported blog posts and
  docs keep their `linuxserver` names on purpose.

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
  - The workspace recipe mentions "contracts models"; there are none.
  - The hub's fixtures README names `mod-list.yml`, but the file is `mods.yml`.
- **The triage bot needs its own App and key in the real org.** Create a `linuxserver` App from the prefilled form
  in `triage/deploy/README.md`, an API key in a workspace with a spend limit, and set `TRIAGE_AUTHORS=external`,
  `TRIAGE_ORG`, `TRIAGE_CONTROL_URL` and `TRIAGE_SITE_URL`. Its footer and prompt say "playground".
- **Fork approvals.** Fork runs need a maintainer to approve them (`all_external_contributors`). Decide
  whether a contributor tier can approve.
