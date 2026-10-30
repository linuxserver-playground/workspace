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
- **Base images and tools are kinds, not categories.** `image.yml` `kind` is optional and defaults to
  `app`, an application users deploy and leave running: that is what the stores, the install artefacts and the
  v1 image list are for. Only the `baseimage-*` repos set `base`. Everything else that is not a long-running app
  sets `tool`: images run once as a command (ffmpeg, qemu-static), the project's own helpers (xvfb, build-agent)
  and binaries other images copy in (yq, unrar). They build, test and release like any image, but the site
  lists them on their own tabs of the images section (a tool's page leads with its README usage), and the hub
  leaves them out of the stores, the install artefacts and the v1 image list. Tools need no mod logic of their
  own. The categories stay as LinuxServer curated them in readme-vars.
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
- **Every upstream is checked hourly, as Jenkins' external triggers were,** so the playground carries live's
  build load. Typed `upstream.version` sources come first (`github_release` reads GitHub's latest release, as
  `github_stable` did; `deb_packages`, `alpine_apk`, `arch_package`, `json`, `regex`, `static`, `combined`), and
  `command` stays for what none of them can say. Control runs a `command` as nobody through doas and a fixed
  wrapper: empty environment, its own directory, ulimits, a kill at 120 s, and `/config` and s6's container
  environment closed to it. Live branches are pushed only by the org, so that is enough; nothing more is
  claimed for it. Only `os` (the package check) and `deb_repo` (docker) are not checked hourly.
- **Control is a small always-on server** (n97, a mini PC, for the playground; a data-centre server in
  production) and stays light. It handles webhooks,
  live status, the queue, scheduler decisions, badges, member actions and notifications. Everything derived
  from releases is rendered by the hub on Pages or by the site.
- **Work that is not a build runs on control, not on runners.** This covers registry copies, git mirroring and
  backups: the 20 concurrent job slots are for builds.
- **Nobody babysits GitHub's lapses.** Every network call in the workflows retries network-class failures with
  backoff (`retry` and `retry_ghcr` in workflows' `scripts/lib.sh`, `netretry.py`) and fails fast on real errors.
  The third-party steps that cannot use those (checkout, the artifact uploads and downloads) get a second attempt
  inside the run instead: a retry twin of each checkout step and the `artifact-upload` and `artifact-download`
  composites, never the image build or the tests, which may fail for real.
  What outlasts that, control heals: it repairs missed webhooks (`heal.py`), retries a failed Pages deploy with
  backoff, and re-runs a live build once when every failed job failed on an infrastructure step, never on the
  image build or the tests (`recover.py`). Discord hears only what control gave up on, grouped hourly.
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
- **Control archives each live release's run on its Release.** GitHub deletes run logs after 90 days, and the
  Release is the one link to an old build that lasts. After the run completes, control attaches `run.json` (the
  run's jobs and steps from the API, never log text) and `logs.zip` (GitHub's log archive). The logs of a public
  repository are already public and masked when written, so this exposes nothing new; control still skips
  `logs.zip` when a credential pattern matches.
- **Control never changes repository settings.** It holds no Pages or Administration permission, which would
  let a stolen App key delete repositories or lift their protections. Whoever creates an image repository turns
  on its Pages (Actions build, no branch rule on `github-pages`, so every live branch can deploy), as the
  new-image recipe says; control only reports an image repository without Pages.
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
- **An AI first responder answers new issues and pull requests** (`triage`, workspace issue #6). A wrong first
  answer that a maintainer corrects beats days without feedback. It runs on control's server as its own
  container with its own GitHub App (comments and labels only) and the only Anthropic API key; control holds
  neither, and the bot holds no credential of control's. It learns of threads by polling control's public
  `/api/issues.json` and `/api/pulls.json` every 30 seconds, in production too: no webhook, no open port.
  Control moves a thread's `updated_at` on every comment so the author's replies show. It reads the hub's
  `data` branch and the site's docs from hourly shallow clones, never the Pages API. The model gets read-only
  tools only and returns structured output; the bot's code posts one comment, marked as AI-written, and labels
  from an allowlist. When the answer depends on the upstream application, Sonnet hands up to three questions to a
  research assistant, Haiku 5.5 at a twentieth of the price, with web search, web fetch and read-only GitHub over
  any public repository (upstream code at the version we ship, releases, changes between versions, issues): it
  reads much, Sonnet judges and writes. The comment is a short reply with the evidence and its links in a
  collapsed section. Thread text and research findings are untrusted: one core rule in each prompt, nothing either
  model can call writes, and GitHub reads are public repositories only. Sonnet 5.5, a self-imposed $100 a month
  cap under a workspace spend limit, counting both models and the searches. No backfill; bots and
  `no-bot` threads are skipped; at most three follow-ups to the author. In the playground it answers members
  too, for demonstration (`TRIAGE_AUTHORS=all`); production answers only people outside the team. Discord is
  out of scope for now.

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
  keeps the same code (`builder.derive`) for older releases.
- **The release path never waits for slow work.** The hub's Deploy only ingests and publishes; stars,
  the mods and PRoot Apps indexes and the pushes to the store repositories are `refresh.yml`'s, hourly, and
  each writes only its own files in `data/` so both commit without conflicts. Each is one job, because every job
  waits for a runner slot on its own.
- **The site renders a build it predates from the hub.** Pages answers a new build's URL with the 404 page,
  which renders the build page in the browser from the hub's API with the same components as the static page.
  A release is on the website once the hub serves it; the site's own rebuild only makes it static. Control's
  Discord hold treats the hub serving the build as live.
- **PRoot Apps is the site's app catalogue,** as Flathub is Flatpak's: `/proot-apps/` shows how to install the CLI,
  then every app proot-apps' `metadata/metadata.yml` does not mark `disabled`, with its install command, whether or not
  the playground has built it yet. The hub indexes the file hourly (`/api/v1/proot-apps.json`), and the site keeps the
  icons as small PNGs. Every Selkies image page says it supports PRoot Apps and links there. The page features
  proot-next, the engine under every app, with links to its repository, docs, issues and Discord.
- **The site asks for people, not money.** The project's shortage is contributors, so the header's button is
  Contribute (Donate stays in the footer and the mobile menu), the home page closes on a call for contributors,
  and `/contribute/` with the docs' Contribute section is the way in. It leads with the harness: an AI agent that
  knows the system lowers the bar to a first pull request. Image, mod, fleet, docs and PRoot Apps pages each carry
  a "help with this" panel with prompts to hand an agent (`ContributeCallout`, `src/lib/contribute.ts`). The
  rules stay the same for everyone: AI use disclosed, a person accountable for every line.
- **Image pages lead with what the app looks like:** the latest build's CI screenshot (amd64 first) sits beside
  the header, with a lightbox, and links the build's test report.
- **Generated data lives on a `data` branch with one commit,** never on `main`. The hub's `data/` and the site's
  snapshots are rebuilt by CI all day (over a hundred commits a day each), and as commits on `main` they grew both
  repositories by several megabytes a day without bound, buried the code history and rode along in every clone.
  Each publish now replaces the branch's commit with a new root commit, pushed with a lease; a writer that loses
  the race merges its own files onto the winner's three-way (the hub's Deploy and Refresh write different
  files), and a conflict fails the run instead of dropping data. The data is mostly a cache: the Releases stay the
  source of truth, the hub keeps the newest 5 builds per branch, and the site's refresh starts from the restored
  snapshot so it stays incremental under the Pages rate limit. What cannot be rebuilt cheaply (the hub's full
  `history.json`, the site's snapshot without a full refresh) is covered by a daily copy kept a week as
  `refs/data-history/<date>`, and a publish that drops more than a tenth of the files is refused. The website
  editor is unaffected: its branches and pull requests carry only content. The site clones with `filter:
  blob:none`, since its git-dates need only commits and paths. The data was also removed from the history made
  before the change (2026-10-27), and the commits that held nothing else went with it.
- **Heavy data is served by each image repository's own Pages,** not by the hub. One hub Pages site holding every
  build's screenshots, logs and file trees was 434 MB of a 1 GB cap and grew with the fleet; split across the
  image repositories, storage grows with the number of images. The Publish job of every live release, and a
  `reason: pages` dispatch, assembles the site from the newest 5 releases of each live branch and deploys it from
  an artifact (CONVENTIONS §6, "Repo Pages"): test report files, `files.<arch>.json.gz` and
  `packages.<arch>.json.gz`. Nothing is committed to the image repository and no state is kept between deploys,
  so a lost deploy is repaired by the next. Pages answers every request with `access-control-allow-origin: *`,
  so the site reads them from any domain; Release assets send no CORS headers, so the browser never fetches one
  and they are only download links. Releases stay the archive of everything.
- **The site shows the newest 5 builds per branch;** the hub keeps the same 5. An older release has no site page:
  the image page's older releases link its GitHub Release, its `run.json` and its run.
- **An init unit belongs to the repository that ships it, and its script is read where it belongs.** ci mounts the
  repository's `root/` (`IMAGE_ROOT`): the units under its `etc/s6-overlay/s6-rc.d` are the image's own and carry
  their run script in `init_graph`; every other unit is a base image's, at any depth, with no script (a root base
  built from scratch owns everything, s6-overlay's `user` bundles included). The build page links each inherited
  unit to the build of the base that defines it and reads the script from there, walking the chain of bases
  (selkies on ubuntu) through the hub: the exact base build by its `index_digest`, else the newest build of the
  floating tag, marked as such. Chosen over copying every base's scripts into every build because a copy cannot
  say which base a unit came from once bases stack, and would repeat the same scripts in a thousand records. The
  comparison against the base image inside ci was never reached in practice (the base is not in the runner's
  daemon), which is why records made before 2026-10-30 list an intermediate base's units as the image's own; the
  site reattributes those when the base owns a byte-identical script.
- **Vulnerabilities** are shown on build pages, with backport-aware framing, for users who look for them; they
  are never a headline and not on image pages. They are the state of the image when it was released, best
  effort and informal, not a live security feed or an authority: every build scans itself once (in its
  `record.json`), nothing is rescanned, and the scan is served as `vulns.json` from the image repo's Pages with
  its database date.
- **Every hub run reconciles the organisation.** A dispatch's payload is only a hint: GitHub drops all but one
  pending run per concurrency group, so each run reads every `image.yml` and the newest releases of every repo
  over GraphQL (about 15 seconds) and ingests every release `data/` lacks, and every held release whose
  `build.json` was uploaded an hour or more after the held record was built: a rebuild of an already released
  head republishes under the same tag (workflows' `head_already_released`), and the hub, then the site's refresh,
  take the new record. The dispatch's tag is forced in the same run so a quicker rebuild is not missed.
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
