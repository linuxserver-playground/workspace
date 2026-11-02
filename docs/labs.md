# Labs

Labs is a second organisation, `linuxserverlabs-playground`, for container images of software that is not yet
proven. The pipeline is the same as the main org's; the bar for the software is lower. A new project that would
take years to earn a LinuxServer image can publish in Labs, be used and get known there, and graduate to the main
org once it is good, popular and maintained. In production the org is `linuxserverlabs`. The old
`linuxserver-labs` was an earlier experiment and is left alone.

The settled points are in [DECISIONS.md](../DECISIONS.md) under "Labs". This page is the design and the plan.

## What Labs is

- **Docker images only.** No Labs mods and no Labs PRoot Apps. Labs images run on the playground's base images, so
  `DOCKER_MODS` with the main org's universal mods works on them at runtime.
- **The same process as the main org.** Outside developers never get push access. They file a proposal and open
  pull requests from forks. Team members create repositories, merge, and decide what goes live. A Labs image
  repository's `maintainers` are credit and who gets mentioned, never access.
- **Labs admins and moderators are a GitHub team in the Labs org.** That is about who reviews and merges there,
  not about the site or the pipeline.
- **GHCR only, now and after the cutover.** The main org will push to more registries later; Labs never will.

## Isolated and shared

| Piece | Labs | Why |
| --- | --- | --- |
| Org, GHCR namespace (`ghcr.io/linuxserverlabs-playground/<name>`), org secrets | Its own | The namespace tells users the image is unreviewed software. |
| Control | Its own instance of the same image, with `GITHUB_ORG`, its own GitHub App, OAuth App and Discord webhook (a Labs builds channel) | A Labs key or webhook can only reach Labs. |
| Hub | Its own deploy of the same code, with mods, PRoot Apps and stores off | Labs data never mixes with the main fleet's stores, v1 image list or health. |
| Runners | The Labs org's own 20 concurrent jobs | Labs builds can never take the main fleet's slots. |
| Workflows, builder, ci, dumper, base images | Shared | Labs repositories call `linuxserver-playground/workflows@v1`. The workflow already derives the image path from the repository owner. |
| Site | Its own build and deploy of the same code (`linuxserverlabs-playground/site`, Labs mode), with its own data snapshots and Pages | Labs refreshes and failures never touch the main site's, and Labs control rebuilds it inside its own org. |
| Harness | Shared | One guided entry point with a Labs path. |

No credential crosses between the two orgs. The Labs hub and the Labs site are thin repositories whose workflows
call the main hub's and the main site's (`deploy-run.yml`), so there is one codebase; their data branches, Pages
and dispatches stay in the Labs org.

Secrets are passed to the shared workflows by name (builder's generated `build.yml` and `pr-report.yml`), because
GitHub's `secrets: inherit` passes nothing to a workflow in another organisation.

## The bar

Each rule is something the proposal check or `builder check` can verify.

- **The upstream is owned by an organisation,** on GitHub (preferred) or any git host, never a personal account.
  No exceptions. An organisation is free to create, and a project that grows moves out of a personal account
  anyway, so that step happens before Labs.
- **An approved open-source licence.**
- **Stable, versioned releases we can ingest.** A typed version source on stable releases, with `require_assets`
  naming what the Dockerfiles download. Release assets are preferred. Building from the release's source is
  allowed when the project needs it. Asset names stay the same from release to release.
- **A self-hosted web app,** `kind: app`, on a playground base image, following the LinuxServer container design:
  s6, `PUID`/`PGID`, state under `/config`, a web UI on a port, and the selkies base for a desktop GUI.
- **Works with just the container.** An embedded database (SQLite or similar) must be an option. If the app needs
  a server database, the image bakes in a fallback started by its own init. No required companion containers.
  Testing then never needs extra infrastructure.
- **No paywalled shell apps.** An app whose main function is a vendor's hosted service, such as a glorified web
  link or a web server hosting a login page, is out. An open-source app that calls a hosted API is fine when the
  endpoint is configurable. For example, an AI app that works against Ollama or any OpenAI-compatible server
  qualifies.
- **Passes `builder check` and the generic ci smoke tests:** every service stays up, and the web endpoint answers
  below 500.
- **amd64 only is allowed;** arm64 is encouraged.
- **A unique name** across Labs, the main org and live `linuxserver`, so graduation never collides.

## From proposal to live

1. **Proposal.** The Labs page on the site explains the process and links a new issue in
   `linuxserverlabs-playground/proposals`, using a structured issue form. The harness's propose-image playbook
   fills in the same form. Its fields serve three purposes:
   - **Weed out early:** checkboxes, each with a URL as proof: owned by an organisation, the licence, the latest
     stable release, asset names stay the same, works with just the container, no required vendor account,
     telemetry disclosed and optional.
   - **Build without asking anything:**
     - upstream repo;
     - release asset per architecture, or "build from the source release";
     - runtime and version;
     - web UI port;
     - where the app writes state;
     - required environment variables;
     - embedded database setting;
     - supported architectures.
   - **Try it in a sandbox:** the first-run steps (default login or setup wizard, and what working looks like),
     and a screenshot.
2. **First check, by a workflow in `proposals`.** On every opened or edited issue it reads the form and checks
   it against the real upstream with `GITHUB_TOKEN` only, no AI and no other secret: the owner's account type,
   the licence, the latest stable release and its asset names, name collisions with Labs, the main org and live
   `linuxserver`. It keeps one comment up to date with what passes and what is missing, and labels the issue
   `meets-bar` or `needs-info`, so no member spends time on a proposal that fails the bar. Upstreams off GitHub
   get the checks their host's API allows, and a member checks the rest in the trial.
3. **Trial, by a member.** `./harness labs try <issue>` builds an image from the issue and runs it in a throwaway
   container: no host mounts, no credentials, and no network beyond what the app needs. It runs the ci smoke tests
   and takes screenshots locally, and opens the UI on localhost. This is where an app that is not really
   self-hosted shows.
4. **Elevate, by a member.** `./harness labs accept <issue>`:
   - creates `docker-<name>` in the Labs org, turns on its Pages (control cannot change repo settings), and adds
     the `labs-pending` topic;
   - pushes an "Image pending approval" `main` branch: a short README and the generated `pr-report.yml`, but no
     `image.yml`. Discovery treats a `docker-*` repository without `image.yml` as a helper repo, so nothing builds
     on `main`. `pr-report.yml` has to be there, because its `workflow_run` and `pull_request_target` triggers
     only run from the default branch.
   - pushes the scaffold built from the issue to a branch and opens the pull request. The PR body links the
     issue and credits the proposer, who is also in `maintainers`; commits carry no trailers.
5. **Review.** The PR build publishes to `untrusted-pr/<name>` (a branch in the org's own repository needs no
   `safe-to-publish`). It posts the report comment: image details, pull command, tests per arch, screenshots and
   package table, so other members can review and pull it. The proposer iterates through fork PRs into that
   branch, or comments and leaves the edits to the member.
6. **Live.** A member merges. `release.branch: main` makes `main` live. Dispatch the first build: a brand-new
   repository runs a workflow for only one of its first pushes. Remove `labs-pending`; Labs control discovers the
   image, and the Labs hub and site follow.

## The Labs site

The same site code, built with `PUBLIC_SITE_MODE=labs` and the Labs hub as `HUB_URL`, deployed from
`linuxserverlabs-playground/site` to `https://linuxserverlabs-playground.github.io/site/` (production:
`labs.linuxserver.io`). The image, build and live-build pages are the main site's, unchanged. Labs mode changes the
layout only: a notice under the header on every page, a Labs badge, its own navigation and footer, and no docs, blog,
mods, PRoot Apps or stores (those link to the main site). The main site links to it from its footer.

- **Home page:** what Labs is, the bar, the steps above, and the button to the proposal form, then the images in
  Labs.
- **Pending approval, public:** repositories with `labs-pending`, each linking its PR and report. A member has
  tried each one and put it forward, so they are worth showing.
- **Proposals, only for signed-in team members:** the open issues in `proposals`, read from Labs control's public
  issues API. Anyone can file one, so the site does not advertise them. Hiding them from signed-out visitors is
  only presentation: the issues are public on GitHub.
- **Image and build pages:** the main site's, under the Labs notice, with no store templates; later the
  maintainers in the header and the graduation scorecard.
- **Fleet:** the Labs board from Labs control (it allows the Labs site's origin), read-only. Member actions on Labs wait until Labs control has its own
  sign-in; Labs admins act on GitHub meanwhile.

## Staying in Labs

The bar to get in is low, so an image that stops working is removed automatically. Labs control flags a release
problem by opening an issue on the image repository that mentions its maintainers:
- a `require_assets` hold that lasts (renamed or missing assets);
- red builds;
- no stable upstream release for a long time.

Repeated or unanswered flags lead to archiving after a grace period. Archived images keep their page with an
`archived` flag, as in the main org.

Starting values to settle when this is built: a hold or red build lasting 14 days opens the issue; 30 days with
no fix archives the image; 12 months with no upstream release flags it.

## Graduation

1. **The scorecard,** from the Labs hub: time live, green-build rate, GHCR pulls, stars, issue response time. It
   informs the team's decision and never makes it.
2. **The main-org checklist:**
   - the proxy block;
   - categories;
   - full documentation;
   - arm64 where upstream supports it;
   - a member's review of the Dockerfiles.
3. **Transfer the repository** to the main org. GitHub keeps its history, issues and stars, and redirects the old
   URL. Turn on Pages as in the new-image recipe and run a live build. Then, with no further steps:
   - main control discovers it;
   - the Labs hub drops it on its next reconcile;
   - the main site gains the image's pages, and the Labs site loses them, on their next builds;
   - Discord announces it.
4. **The Labs image stays published** with a moved notice. The container design is the same, so users only change
   the `image:` line.

`./harness labs graduate <name>` should do steps 3 and 4 for a member.

## Build-out order

1. **No hard-coded org:**
   - the hub's `ORG` constant (`lsio_hub/config.py`) and the names built from it come from the environment, and
     its deploy and refresh become reusable workflows with an `org` input;
   - check that every workflow step takes the org from the repository owner, as the image path does. Control
     (`GITHUB_ORG`) and builder (`BUILDER_*`) already take it from the environment.
2. **Builder:**
   - a `maintainers` field in `image.yml` (`mod.yml` has one);
   - a Labs profile in `builder check`, chosen from the repository owner, that enforces what in the bar is
     checkable.
3. **Stand up the org:**
   - the Labs org, its org secrets, the Labs admins team;
   - Labs control with its App and Discord webhook;
   - the Labs `hub` repository;
   - `proposals` with its issue form;
   - a `.github` repository with the Labs rules and contributing guide.

   Then take two or three apps through the whole path.
4. **The Labs site:** Labs mode in the site, its callable deploy, and `linuxserverlabs-playground/site`.
5. **Harness:** the Labs developer role, the playbook that helps a developer make their app easy to self-host and
   publish releases from their own repository, then package it; `labs try`, `labs accept`; the propose-image
   playbook and the site's "Coming: Labs" panels repointed.
6. **Staying and leaving:** flags and archiving in Labs control, the scorecard, `labs graduate`.
