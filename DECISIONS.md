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
  80 MB on webtop.
- **File trees** come from `dumper`, a static Rust walker mounted into ci (not embedded in images). The tree
  shows files only: no per-file layer numbers and no package ownership.
- **Screenshots.** ci waits at least 30 s on amd64 and 90 s on arm64 for selkies, kasmvnc and rdesktop
  bases.
- **Build reports.** A release's report is its build page on the website; the ci harness writes no HTML
  report of its own. A build without a page is reported where GitHub shows it, with one smoke-test report
  (`workflows/scripts/pr_report.py`: tests per arch, screenshots, runtime, package changes, log tails): a PR
  build as its pull request comment, a branch or live build at the top of its run's job summary, which
  control's notifications link. The site and the hub never render branch builds; they stay lean, and data
  that is only wanted on demand stays where the build left it.

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
- **Control holds every notification and GitHub App credential.** Image repos never hold a hub token or a
  Discord webhook.
- **A release's Discord message is held until its site page is live** ("passed, publishing"), so it never
  links a 404. Past 30 minutes control posts where it is stuck (hub or site); it stops watching after 24 h.
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
  the mods index and vulnerability rescans are `refresh.yml`'s, hourly, and each writes only its own files in
  `data/` so both commit without conflicts.
- **The site renders a build it predates from the hub.** Pages answers a new build's URL with the 404 page,
  which renders the build page in the browser from the hub's API with the same components as the static page.
  A release is on the website once the hub serves it; the site's own rebuild only makes it static. Control's
  Discord hold treats the hub serving the build as live.
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
