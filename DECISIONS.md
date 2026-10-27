# Decisions

Settled choices for the v2 playground, with the reason where it is not obvious. Treat them as fixed. To
change one, ask the maintainers first, then update this file in the same change.

## Scope

- **A total refresh, not a migration.** Nothing stays compatible with `jenkins-vars.yml`, `readme-vars.yml`
  or the Jenkins-generated file set. What carries over: the s6 base images, the mods model, the content of
  readme-vars, and the test harness ideas.
- **GitHub only** for the proof of concept: Actions, GHCR, Releases, Pages. No registry mirroring, no pushes to
  several registries, no Scarf. GHCR is all the live release needs, because lscr.io (Scarf) proxies GHCR.
  Other registries, git mirrors and backups come later. They will be a control-run phase that never holds up
  the GHCR release and never uses a runner (workspace issues #4 and #5).
- **The whole fleet,** every `linuxserver/docker-*` image that is not deprecated, staged with its live
  branches (`docs/conversion-report.md`). Deprecated live branches are not converted. Names the schema
  rejects (a `.` or `_`) wait on a decision.
- **riscv64 is out of scope.**
- **Build what upstream builds.** The playground exists to show that 20 GitHub runners carry the whole
  workload Jenkins carries today, so nothing upstream still builds is pruned to make it fit: the images, the
  batch projects (wheelie, proot-apps, selkies-layers) and the mod upstream triggers. Only what upstream itself
  no longer builds is left out. `docs/github-runners.md` holds the measurements.

## Image repos and the pipeline

- **One manifest per branch**, `image.yml`, validated by a JSON Schema. Everything else in an image repo is
  generated from it.
- **Base images and internal tools are kinds, not categories.** `image.yml` `kind` is optional and defaults to
  `app`; only the `baseimage-*` repos set `base` and the internal tools (xvfb, yq, unrar, build-agent…) set
  `tool`. They build, test and release like any image, but the site lists them on their own tabs of the images
  section, and the hub leaves them out of the stores, the install artefacts and the v1 image list. The
  categories stay as LinuxServer curated them in readme-vars.
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
  80 MB on webtop. `docker buildx imagetools` and Docker Scout read it. Trivy's `--sbom-sources oci` does
  not: it only reads OCI referrers, never attestations inside an index (BuildKit's own included), so it
  scans the layers itself. That is accepted, and no referrer copy is published: vulnerabilities are shown on
  the site per build (workspace issue #2).
- **File trees** come from `dumper`, a static Rust walker mounted into ci (not embedded in images). The tree
  shows files only: no per-file layer numbers and no package ownership.
- **Screenshots.** ci waits at least 30 s on amd64 and 90 s on arm64 for selkies, kasmvnc and rdesktop
  bases.
- **Smoke tests are generic, not per image.** After init, ci checks what holds for every image type: every
  s6 service it wants up stays up (FAIL), the web endpoint answers below 500 (FAIL), the required
  `runtime.ports` listen (WARN), and the logs of the runtimes it runs (.NET, Java, Node.js, Python, PHP, nginx,
  uWSGI) carry no known failure line (WARN). Runtimes are recognised from the running processes, never from
  packages alone.
- **Build reports.** A release's report is its build page on the website; the ci harness writes no HTML
  report of its own. A build without a page is reported where GitHub shows it, with one smoke-test report
  (`workflows/scripts/pr_report.py`: tests per arch, screenshots, runtime, package changes, log tails): a PR
  build as its pull request comment, a branch or live build at the top of its run's job summary, which
  control's notifications link. The site and the hub never render branch builds; they stay lean, and data
  that is only wanted on demand stays where the build left it. The Publish job's summary is the run page's only
  box: the result, then the report (pull command, screenshots and tests first), then the build details.

## Mods

- **One branch per mod** in `docker-mods`, named `<target>-<name>`, with `mod.yml` as its only metadata.
  `README.md`, `AGENTS.md` and `build.yml` are rendered by `builder render-mod`. Every legacy
  linuxserver/docker-mods mod was converted with its history (`builder.mods.convert`), except upstream work
  branches and deprecated mods that no longer build.
- **`mod.yml` `images` replaces `mod-list.yml`:** the images a mod is meant for besides its target. The hub's
  `applies_to` is the target then `images`; image pages and config labs list an image's own mods, then the
  universal mods curated for it, then the rest. Deprecated mods are left off image pages and labs.
- **Every mod has a site page,** `/mods/<branch>/`, with its docs; the mods index, image pages and the
  config lab link it.
- **Mods that pin an upstream tool are rebuilt by the central scheduler,** not by per-mod triggers. `mod.yml`
  `upstream` reuses image.yml's version sources and resolver (`combined` joins two, for docker and compose);
  the build passes the version as `MOD_VERSION` and tags `mods:<branch>-<version>`, and control checks hourly
  and dispatches the branch's build when that tag does not exist. The GHCR tag is the record of what was
  built, as Docker Hub's was for the Jenkins External-Triggers jobs. Triggers that were dead upstream
  (nginx-proxy-confs, sabnzbd-par2cmdline-turbo, transmission-web-control) were not carried over.
- **A mod builds every version line upstream builds,** declared in `mod.yml`, not in a workflow.
  `upstream.version` is the default line, the one `mods:<branch>` follows; `upstream.lines` names the others
  (code-server-golang: `previous`, Go's older supported release, and `unstable`, its release candidate), and
  `tags` (`major`, `minor`) are the floating `-X` and `-X.Y` tags a line moves. Control checks every line and
  dispatches the first missing one with its `line`, one build of a mod at a time (the next line goes out as soon
  as the branch's run completes, not at the next hourly check); a line's build never moves
  `mods:<branch>`. Only a branch with lines has the `line` input in its generated `build.yml`, so the other
  mods' files stay identical.
- **A push that touches `mod.yml` refreshes that mod in control at once,** as a push does for an image's
  `image.yml`; the 30-minute discovery stays the backstop.
- **The mod page shows what a user pins:** the version built and when, `mods:<branch>-<version>` beside the
  floating tag, and each line's version, date and tags. The hub's hourly refresh reads them from the GHCR
  `mods` package into the mods index (`builds`), resolving the extra lines with workflows' own resolver
  (`workflows@v1`, not a copy), so a new mod build shows on its page after the next refresh.
- **Helper repos** (`docker-*` without an `image.yml` on the default branch, such as `docker-mods`) are not
  images: the fleet board lists them apart with their branch build health and never links an image page.

## Control plane

- **A central scheduler** replaces every per-repo cron: hourly upstream checks, hourly release checks, and
  weekly package checks.
- **Control is a small always-on server** (n97, a mini PC, for the playground; a data-centre server in
  production) and stays light. It handles webhooks,
  live status, the queue, scheduler decisions, badges, member actions and notifications. Everything derived
  from releases is rendered by the hub on Pages or by the site.
- **Work that is not a build runs on control, not on runners.** This covers registry copies, git mirroring and
  backups: the 20 concurrent job slots are for builds.
- **Batch build projects share the org.** wheelie, proot-apps and selkies-layers are brought into the
  playground org, not a separate build org. They are not images: their builds are capped so they always leave
  runner slots free for image, hub and site builds, and the site shows them apart from the image fleet.
  Control starts each run with its matrix width (`parallel`) worked out from the jobs already running.
- **proot-apps stays forkable.** Its build logic follows the repository owner and name, and a fork with
  Actions enabled builds on its own schedule with the default cap. Control-driven scheduling is opt-in, by a
  repository variable only our org sets.
- **wheelie only builds what PyPI lacks.** Most of its packages now ship musl and glibc wheels for both
  arches upstream, so it builds a wheel only when no compatible one exists (bluepy, and new CPython versions
  after an Alpine bump). Wheels go to GitHub Release assets and the index to Pages; no Jenkins, no S3. The
  Home Assistant and SCI variants, disabled upstream since 2024 and 2023, are not carried over.
  Images keep `--find-links` to the index: it costs nothing while PyPI has the wheels, and the gap check
  fills it after the next CPython bump. Packages join `packages.txt` only when compiling them dominates an
  image's build or breaks it, not because an image compiles them. The live index stays append-only at
  cutover: mods and outside projects read it, so no page or legacy wheel is removed.
- **Control holds every notification and GitHub App credential.** Image repos never hold a hub token or a
  Discord webhook.
- **A release's Discord message is held until its site page is live** ("passed, publishing"), so it never
  links a 404. Past 30 minutes control posts where it is stuck (hub or site); it stops watching after 24 h.
- **Discord follows the Jenkins colours:** green for a live success, dark green for a dev or PR success, red
  for a live failure, dark red for a dev or PR failure. A build without a site page links its report: a PR
  build its report comment, any other its run's summary. A package check is announced only when it fails;
  the release build it dispatches is the one that counts.
- **Fleet auth on the site** uses control's session cookie (`SameSite=None; Secure`, CORS with credentials,
  a CSRF header from `/api/me`). Production would share one registrable domain. In the playground, test member
  actions in Chromium.
- **Member sign-in** is a classic OAuth App, so GitHub shows no "act on your behalf" consent. Actions use the
  App installation token.
- **The website editor commits as the member.** It is for quick edits and new posts by anyone on the team,
  technical or not; larger changes are made in git. The pages are its interface: people who can edit the site
  see Edit and Delete on posts and docs pages, New post on the blog and New page on docs sections, and every
  open edit where it belongs (on the page it changes; new posts and pages on the blog or their section). There
  is no overview page. Markdown beside a preview plus a details form, no WYSIWYG; Preview renders with the
  site's own layout components. Images, galleries, videos (committed as uploaded, never transcoded) and YouTube
  embeds (the only frames allowed). New sections and layout changes stay in git.
- **One change, one branch, one pull request.** A save is a commit on `edit/<login>/…`; opening someone's open
  edit joins it rather than starting a second one. The pull request is the draft and merging it publishes it,
  so posts need no `draft:` and no `date:` (dates come from first-parent git history). A non-technical editor
  writes; a reviewer fixes and merges on GitHub. Deleting is the same: one PR removes the page and its files,
  with no redirect.
- **Editing asks once more,** for the GitHub App's own user authorisation (never a classic OAuth scope, which
  would reach repos outside the org). Control keeps that token encrypted, uses it only on the site repo's
  content and media, and revokes it on sign-out.

## Hub and site

- **The site is the single pane of glass.** Nobody should need to leave it except for issues, PRs and raw run
  logs. Image pages carry the complete documentation rendered from the manifest. Anything only a README or the
  hub says is a gap in the site. The separate docs site is archived; non-image docs and the blog live in the
  site as content collections. The fleet dashboard lives in the site too.
- **Release notes render as GitHub does.** Both sections (LinuxServer and upstream) are GitHub-flavoured
  Markdown with raw HTML allowed, rendered at site build time and sanitised to an allowlist (no scripts, styles,
  frames, forms, event handlers or non-http(s) URLs). Upstream notes may be HTML from a feed (`upstream.notes`
  type `rss`); they are stored verbatim and only sanitised where they are shown. A build page rendered live
  from the hub (below) shows the notes as plain text until the next site build renders them.
- **Data about a build is made by the build.** The publish job derives `record.json` (`builder record`): the
  package tables, the diff against the previous release of the branch, a grype scan of both architectures and
  the base image's layers. Image builds may take a minute longer for it, so that the hub only indexes. The hub
  keeps the same code (`builder.derive`) for older releases and for rescans.
- **The release path never waits for slow work.** The hub's Deploy only ingests and publishes; stars, GHCR tags,
  the mods and PRoot Apps indexes, vulnerability rescans and the pushes to the store repositories are `refresh.yml`'s, hourly, and
  each writes only its own files in `data/` so both commit without conflicts. Each is one job, because every job
  waits for a runner slot on its own.
- **The site renders a build it predates from the hub.** Pages answers a new build's URL with the 404 page,
  which renders the build page in the browser from the hub's API with the same components as the static page.
  A release is on the website once the hub serves it; the site's own rebuild only makes it static. Control's
  Discord hold treats the hub serving the build as live.
- **PRoot Apps is the site's app catalogue,** as Flathub is Flatpak's: `/proot-apps/` shows how to install the CLI,
  then every app proot-apps' `metadata/metadata.yml` does not mark `disabled`, with its install command, whether or not
  the playground has built it yet. The hub indexes the file hourly (`/api/v1/proot-apps.json`), and the site keeps the
  icons as small PNGs. Every Selkies image page says it supports PRoot Apps and links there.
- **Generated data lives on a `data` branch with one commit,** never on `main`. The hub's `data/` and the site's
  snapshots are rebuilt by CI all day (over a hundred commits a day each), and as commits on `main` they grew both
  repositories by several megabytes a day without bound, buried the code history and rode along in every clone.
  Each publish now replaces the branch's commit with a new root commit, pushed with a lease; a writer that loses
  the race merges its own files onto the winner's three-way (the hub's Deploy and Refresh write different
  files), and a conflict fails the run instead of dropping data. The data is mostly a cache: the Releases stay the
  source of truth, the hub keeps the newest 10 builds per branch, and the site's refresh starts from the restored
  snapshot so it stays incremental under the Pages rate limit. What cannot be rebuilt cheaply (the hub's full
  `history.json`, the site's snapshot without a full refresh) is covered by a daily copy kept a week as
  `refs/data-history/<date>`, and a publish that drops more than a tenth of the files is refused. The website
  editor is unaffected: its branches and pull requests carry only content. The site clones with `filter:
  blob:none`, since its git-dates need only commits and paths. The data was also removed from the history made
  before the change (2026-10-27), and the commits that held nothing else went with it.
- **Heavy data** (file trees) stays on GitHub Releases. Release assets have no CORS headers, so the site fetches
  them through control's CORS gateway, with a loading state.
- **Vulnerabilities** are shown on build pages, with backport-aware framing, for users who look for them; they
  are never a headline and not on image pages. Every build scans itself (in its `record.json`); the hub rescans
  the newest build of each branch when the vulnerability database changes, at most daily.
- **Every hub run reconciles the organisation.** A dispatch's payload is only a hint: GitHub drops all but one
  pending run per concurrency group, so each run reads every `image.yml` and the newest releases of every repo
  over GraphQL (about 15 seconds) and ingests every release `data/` lacks.
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
