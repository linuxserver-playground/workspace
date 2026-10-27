# AGENTS.md - workspace

## Purpose

The starting point for working on the LinuxServer.io v2 playground, the GitHub organisation
`linuxserver-playground`: a proof of concept of LinuxServer.io with no Jenkins. Image repos hold a manifest
(`image.yml`), one shared GitHub Actions workflow builds, tests and releases every image, a hub turns the
release bundles into data and generated artefacts, a control plane schedules builds, and one website shows
all of it. This repo holds no product code. It clones every other repo into `repos/` and explains how they
fit together, so an agent started here can make a change that crosses repos.

Live surfaces:

| What | URL |
| --- | --- |
| Website (the single pane of glass: images, builds, fleet, PRoot Apps, docs, blog, and editing the docs and blog from their pages) | https://linuxserver-playground.github.io/site/ |
| Hub (static API and generated artefacts) | https://linuxserver-playground.github.io/hub/ |
| Control plane (scheduler, webhooks, JSON API, member actions) | https://ci.thelamer.duckdns.org:8443 |
| Images | `ghcr.io/linuxserver-playground/<name>` |

## Getting started

```bash
gh auth login                  # an account that owns or belongs to linuxserver-playground
./bootstrap.sh                 # clone or fast-forward every repo into repos/
./bootstrap.sh --setup         # once: venvs, npm, cargo for the infrastructure repos
./bootstrap.sh --reference     # optional: the read-only linuxserver/* originals, for converting images
```

Re-run `./bootstrap.sh` at the start of every session; others push too. It never merges over local changes.

**Before editing a repo, read its own `AGENTS.md`.** Each one says what may be edited there, how to validate
locally and what its pull request rules are. This file only covers what crosses repos. The contract behind
everything is `repos/builder/CONVENTIONS.md` with the JSON Schemas in `repos/builder/schemas/`; when anything
here disagrees with it, CONVENTIONS wins. The settled design decisions are in `DECISIONS.md`: do not reopen
them without the maintainers.

## Layout

`repos/` (from `bootstrap.sh`, gitignored):

| Repo | Role | A change goes live when |
| --- | --- | --- |
| `builder` | Contracts: `CONVENTIONS.md`, `schemas/`, the `contracts` package, the `builder` CLI (check, render, migrate, snippets, record), `builder.derive` (per-build data, shared by the build and the hub), AGENTS.md templates for image repos | push to main publishes `ghcr.io/linuxserver-playground/builder:latest`; the other Python repos install `lsio-builder` from `builder@main` |
| `workflows` | The reusable `image-build.yml` and `mod-build.yml` plus one composite action per step | the floating tag `v1` moves to the new commit (image repos call `@v1`) |
| `ci` | The container test harness: runs each built image, takes screenshots, emits the release bundle | push to main publishes `ghcr.io/linuxserver-playground/ci:latest`, which workflows pulls |
| `dumper` | Rust static file-tree walker for the bundle (`dumper files`) | a GitHub Release; workflows fetch `releases/latest` |
| `hub` | Ingests each release's `build.json` and `record.json` into `data/`, serves the API on Pages, generates stores, proxy confs, k8s manifests, the mods index, the PRoot Apps index and build reports; `refresh.yml` hourly: stars, GHCR tags, mods, PRoot Apps, grype rescans, pushes to the store repos | push to main, hourly refresh dispatched by control, `repository_dispatch image-released` |
| `site` | Astro website: image pages, build pages, fleet board (live from control), PRoot Apps catalogue, docs collection, blog | push to main, `repository_dispatch hub-updated` (relayed by control after every hub deploy), daily cron |
| `control` | FastAPI GitHub App on n97: webhooks, fleet discovery, central scheduler, `/events`, OAuth sign-in, member actions, Discord | push to main: Publish runs the checks and pushes `:latest`; n97's updater pulls it within 5 minutes |
| `docker-<name>` | One image each: `image.yml`, two Dockerfiles, `root/`; README, AGENTS.md and `build.yml` are generated | push to a live branch builds and releases; any other branch builds to `dev/` |
| `docker-mods` | Mods: `master` holds tooling and the guarded `build.yml`, one branch per mod with `mod.yml` (about 95 branches) | push to a mod branch builds the image (and control's hourly mod check builds a new upstream version of a mod with an `upstream` block, per version line); control re-reads a pushed `mod.yml` at once; the hub's next scheduled or dispatched run reads the `mod.yml` |
| `wheelie` | Python wheel index for the images (`--find-links`): builds only the wheels PyPI lacks, as Release assets, index on Pages | control's hourly gap check dispatches `build.yml` when a wheel is missing; push to main redeploys Pages |
| `proot-apps` | PRoot app images and the `proot-apps` CLI; built to be forked, every name follows the repository. `metadata/metadata.yml` is the site's PRoot Apps catalogue (`/proot-apps/`), through the hub | control dispatches the nightly package check (00:00 UTC), which rebuilds the apps whose packages changed; a push builds the apps it changed |
| `selkies-layers` | Compositor and input layers (kwin, labwc, wtype, xvfb) per distro, copied into baseimage-selkies | control dispatches the nightly build (04:30 UTC); push to main builds |
| `unraid-store`, `umbrel-store`, `runtipi-store` | Generated store repos, pushed by the hub | never edit by hand; change the generator in hub |
| `dot-github` | The org's `.github` repo: profile README, CONTRIBUTING, SECURITY, FUNDING | push to main |
| `harness` | The guided entry point for team members and contributors running an AI agent: role detection, playbooks, the `./harness` CLI, guard hooks | push to main |

`reference/` (from `--reference`, read-only): `linuxserver/docker-ci`, `docker-jenkins-builder`, `docker-mods`,
`templates`, `docker-documentation` and `reverse-proxy-confs`, the Jenkins-era originals. Read them for intent; never copy their
generated output.

## How data flows

1. A push to a live branch of `docker-<name>` (or a scheduler dispatch) runs `build.yml`, which calls
   `workflows/.github/workflows/image-build.yml@v1`.
2. Per arch, on native runners: build to the `build/` staging namespace, test with the `ci` image, one syft
   scan, `dumper files` for the file tree.
3. `publish-manifest` creates the released multi-arch tags (CONVENTIONS §3) and attaches our own SBOM
   attestation. `builder record` derives `record.json`: package tables, the diff against the previous release,
   a grype scan, base layers. The GitHub Release gets the bundle assets with it.
4. The workflow POSTs signed events to control `/events`. Control posts to Discord (held at "publishing" until
   the hub serves the build) and sends the hub `repository_dispatch image-released`.
5. The hub's Deploy reconciles the organisation over GraphQL, ingests every release `data/` lacks (build.json
   and record.json: two downloads each), commits `data/`, renders the API on every core and deploys Pages. From
   then on the build's site page works: the site renders a build it predates from the hub's API on its 404
   page (`LiveBuildPage`).
6. When the hub's Deploy succeeds, control sends `hub-updated` to the site, and the site rebuilds from the hub
   API, which makes the new build pages static. Nobody waits for this step.
7. The site's fleet pages read control's JSON API live, with the session cookie, for anything that changes
   minute to minute.
8. Hourly, the hub's `refresh.yml` reads stars and GHCR tags, rescans vulnerabilities when grype's database moved,
   refreshes the mods index, commits and asks for a Deploy, then pushes the Unraid, Umbrel and Runtipi store repos.

`docs/delivery-latency.md` measures this path and records why it is shaped this way.

Control finds the fleet on its own: every 30 minutes, and on the first push to a new repo, it reads `image.yml`
from every `docker-*` repo. Adding an image needs no change to control, the hub or n97.

## Keeping the harness in step

`repos/harness` is the guided way in for the team and for outside contributors: what this file says tersely,
it says step by step, per role. When a change made from here alters the architecture, update the harness in
the same push or straight after. That covers a new repo or surface, a new data path or API, a changed recipe,
a new rule, a new member action, or a moved URL. The places to check:

- its guides: `guides/system-map.md`, `data-sources.md`, `rules.md`, `gotchas.md`;
- the playbook for the affected request (`guides/playbooks/`);
- the `./harness` CLI, when a command, URL or validation list changed.

A harness that describes last week's system sends every agent the wrong way.

## Change recipes

Run the validation steps from each repo's AGENTS.md before every push. Never claim a test you did not run.

- **New or changed `image.yml` field.** In `builder`: schema, then the `contracts` models, then
  CONVENTIONS, then the renderer and checks, with tests. Push. Then update each consumer: the hub (transform,
  models, generator fixtures), the site (show it on the image page first: the site is where users read it),
  and control if the scheduler reads it. Control and the hub install builder at build time, so they only pick
  up the change after their next push or dispatch.
- **Change to how images build or test.** Edit `workflows` (and `ci` for the harness). Run
  `./scripts/check.sh`, push, then move `v1`:
  `git tag -f v1 && git push -f origin v1`. Verify with a dispatched build of a small image
  (`gh workflow run build.yml -R linuxserver-playground/docker-heimdall`). A change that breaks the
  inputs, outputs or ci interface is a new major tag, not `v1`.
- **Change to per-build data** (a diff field, the package table, the scan). Edit `builder/builder/derive/`, bump
  `record.schema.json` and `contracts_version` if the shape changes, and push builder: every build from then on
  writes it into `record.json`, and the hub uses the same code for releases without one. Then the hub's models
  and responses, then the site's `src/lib/hub.ts` and the build page parts (`src/components/build/`, used by the
  static and the live build page alike). Builds made before the change keep their old record; to recompute
  everything, the hub can derive from the assets (`read_record` returning None).
- **Change to generated image-repo files** (README, AGENTS.md, build.yml). Edit the templates in `builder`.
  Image repos pick them up on their next live build, as one bot commit `Update generated files`. Never
  hand-edit generated files in an image repo: `builder check` fails the build.
- **New image.** Clone `linuxserver/docker-<name>`, create the playground repo
  (`gh repo create linuxserver-playground/docker-<name> --public`) and push the original's branches to it,
  history included. Then, per live branch:
  1. `builder migrate`, review the TODOs.
  2. `builder render`, then `builder check`.
  3. Delete `Jenkinsfile`, `jenkins-vars.yml`, `readme-vars.yml` and the old `.github/`.
  4. Make one commit, `Convert to the v2 layout: image.yml replaces readme-vars and jenkins-vars, generated
     files rendered by builder`.
  5. Point the `FROM` lines at the playground's own images (base images, unrar) where it publishes the tag, in
     a second commit, `Build on the playground base images`, and add the branch to
     `docs/playground-references.md`.

  A branch is live when its own `image.yml` names it in `release.branch` (as `ls_branch` did); the workflow,
  control and the hub all read it from there. The default branch's `release.tags` only advertises tags in the
  README and store pickers, so it may lag a branch that is out for public testing. Leave out live branches that
  readme-vars marks deprecated. The name must match the schema's `name`
  pattern: a `.` or `_` fails it, pending a maintainer decision. Expect to finish by hand what migrate does not:
  - the proxy block, from `reference/reverse-proxy-confs`;
  - categories on branches other than the default;
  - `# shellcheck shell=bash` headers on s6 scripts;
  - `#!/command/with-contenv` shebangs.

  `builder check` rejects the last two. `docs/conversion-report.md` and the converted repos are worked
  examples. The GHCR package is created
  public on the first publish (an org setting); nothing else needs doing. Push only the live branches
  (where `jenkins-vars.yml` `ls_branch` names the branch). On a brand-new repo GitHub runs a workflow
  for only one of the first pushes, so check `gh run list` and dispatch the live branches that got no run
  (`gh workflow run build.yml -R linuxserver-playground/docker-<name> --ref <branch> -f reason=manual`).
- **Site-only change** (layout, docs page, blog post). Edit `site` and validate with its AGENTS.md list
  (check, build, a11y, overflow at 390px). Build from the committed `src/data/` snapshot; don't refresh it
  from the live hub to test (`npm run data`, least of all `REFRESH_ALL=1`): GitHub Pages rate-limits by IP and
  locks the machine out of the hub for half an hour or more. Docs pages and posts are content collections; front matter is
  validated at build time. People edit them from the pages themselves (Edit, Delete, New post, New page, shown
  to people who can edit the site; control's `editor.py`): every change is one `edit/<login>/…` branch and one
  pull request, which a reviewer merges. Open edits show on the page they change, not on any overview. A change
  to the editor spans both repos; `site/scripts/editor-check.mjs` drives it against a fake control plane.
- **Hub generator or API change.** Edit `hub`, update the fixture tests for sonarr, swag and multidb, and
  push. Pages redeploys on push. To force a full refresh: `gh workflow run deploy.yml -R linuxserver-playground/hub`.
- **Control change.** Edit `control`, run its checks, and push to main. That deploys. A red main ships
  nothing, so watch the Publish run. Settings live as defaults in `control/config.py`, so changing one is a
  code change. Only a new *secret* needs n97 (see Secrets).
- **New mod.** Follow `repos/docker-mods/AGENTS.md`: a branch from `template` with `mod.yml`, then
  `builder render-mod`, `tools/check-branch.sh` and `tools/test-mod.sh`. List the other images it suits under
  `images`. A mod that pins an upstream tool's version gets an `upstream` block (image.yml's source types, not
  `os`, `command` or `deb_repo`) and `ARG MOD_VERSION`: control then rebuilds it on every new version
  (CONVENTIONS §3, "Mods"). When upstream ships several version lines at once (Go's two supported releases and
  its release candidate), list the others under `upstream.lines` and the floating `-X`/`-X.Y` tags under `tags`;
  `render-mod` then adds the `line` input to that branch's `build.yml`, and control builds each line in turn
  (`code-server-golang` is the worked example). Control re-reads a pushed `mod.yml` at once. The hub refreshes the mods index only on scheduled or dispatched runs (control dispatches one
  hourly); `gh workflow run deploy.yml -R linuxserver-playground/hub` to see it sooner.
- **Remove an image.** Check nothing depends on it first: no other image builds `FROM` it and no open PRs.
  Then delete the repo and its GHCR packages (`<name>`, `build/<name>`, and any `dev/<name>` or
  `untrusted-pr/<name>`); packages outlive their repo. Everything else follows on its own:
  - control drops the repo on GitHub's `repository deleted` webhook;
  - the hub's next Deploy (within the hour, or `gh workflow run deploy.yml -R linuxserver-playground/hub`) removes
    its data;
  - the site rebuilds without its pages on the `hub-updated` that follows.

  Archiving instead keeps it on the site with an `archived` flag.
- **New `docker-*` repo that is not an image.** Leave out `image.yml`; discovery lists it as a helper repo.
- **New batch build project** (a repo that fans out a big matrix, like proot-apps or selkies-layers). Give
  every fanned-out workflow a `parallel` dispatch input that becomes `max-parallel` (clamp 1–16, default 4),
  one `concurrency` group per workflow, `retry_ghcr` around every registry call (vendored from workflows'
  `scripts/lib.sh`), and gate any cron on `vars.SCHEDULED_BY_CONTROL != 'true'`. Then add it to `PROJECTS` in
  control's `batch.py` and to `batch_live` in `config.py`, and set the variable. Control sizes each run from
  the free slots and posts its failures to Discord. Never dispatch one by hand without a `parallel` that leaves
  the reserve free (`/api/batch.json` shows `parallel_now`).

## Secrets

You need none. Your own `gh` login (as an org member) is all a change requires:

- Image builds, the hub and the site run on GitHub Actions with `GITHUB_TOKEN` plus org-level secrets that
  every repo already inherits (`CONTROL_EVENTS_SECRET`, `CONTROL_URL`, `PACKAGES_TOKEN`, `ATTACHMENTS_TOKEN`,
  `STORE_APP_ID`/`STORE_APP_PRIVATE_KEY` on the hub). A new repo gets them without any setup.
- The control plane holds the GitHub App key, the Discord webhook, the OAuth secret and the session key in
  `~/control/.env` on n97. Its non-secret settings are code defaults, so a normal change never touches n97.
- Nothing local needs a secret either: every repo's tests run against fixtures and mocks.

Only a change that adds a *new* credential needs a maintainer: a new org secret, or a new value in n97's
`.env`. Write the code so that it degrades cleanly when the secret is missing (the hub's store publishing,
for example, skips until its key exists), and ask in the PR or issue for it to be set. Never ask anyone to
paste a secret into a chat, an issue or a file.

## Operating and checking the live system

- Fleet and scheduler state: the site's `/fleet/` pages, or `https://ci.thelamer.duckdns.org:8443/status`
  and `/api/*.json` (listed in `repos/control/README.md`).
- Runs: `gh run list -R linuxserver-playground/<repo>`. Logs are the only reason to leave the site.
- A red build: before fixing anything, tell upstream rot and network flakes from pipeline bugs with
  `docs/build-failure-triage.md`.
- Capacity: the account runs 20 concurrent jobs, and that, not minutes, is the limit (`docs/github-runners.md`).
  Pace mass dispatches, keep the heavy builds apart, and keep work that is not a build off the runners. A workflow
  on the release path (the hub's and the site's Deploy) stays one job: each job waits for a slot on its own, and
  in a burst a small second job waited 20 minutes.
- Member actions (rerun, cancel, dispatch, skip flags) are on the site after signing in with GitHub. Use
  Chromium: the playground's site and control are cross-site, so the session cookie is `SameSite=None`.
- Images under `dev/` and `untrusted-pr/` are unreviewed by design. PR builds are deleted when the PR closes.

## What you may edit

Everything in the playground org: commits, branches, tags and new repos are fine. You may move floating tags
(`v1`) without asking. The real `linuxserver` org (and anything under `reference/`) is read-only: no pushes,
PRs, issues or comments there.

In this repo you may edit this file, `DECISIONS.md`, `README.md`, `docs/`, `bootstrap.sh` (shellcheck clean)
and `.claude/`. When you learn something the next agent needs, a cross-repo rule or a recipe, add it here. Put
anything specific to one repo in that repo's AGENTS.md instead.
When you find something the move to the real `linuxserver` org will have to change (a playground
shortcut, a hard-coded org name, a gap only real contributors would hit), add a bullet to
`docs/live-cutover.md` rather than fixing it then and there.

## Rules for every repo

- Commit subjects are short imperative sentences with no prefixes, no emoji and no trailers of any kind, AI
  co-author lines included (CONVENTIONS §8). Disclose AI assistance in PR descriptions.
- Nothing may contain a credential, and secrets are never printed, copied or committed.
- Nothing may reference a namespace other than `linuxserver-playground`, except links to upstream docs and
  images the playground does not build yet. Images build `FROM` the playground's
  own base images and build layers. `docs/playground-references.md` lists every such rewrite so it can be
  swapped back when this moves to `linuxserver`; add to it whenever you make one.
- The site is the single pane of glass. New data lands on the site first; the hub and README follow.
- Generated files (image repo READMEs, AGENTS.md and `build.yml`, the hub's `data/`, `dist/` and `out/`,
  and the store repos) are never hand-edited. Change the generator.
- Stepping on each other is best effort for now. Re-run `bootstrap.sh`, pull before you push, and when a push
  is rejected, rebase onto the new work rather than force-pushing over it.
