# From release to website: the delivery path

How long a release takes to reach its page on the website, where that time goes, and how the pipeline is
being reshaped so that the time is close to the cost of a single Pages deploy. The numbers in "Measured" are
from 2026-10-26, before the changes below.

## Measured

Control records when a release's `build.summary` arrives (`publish_started_at`) and when the build's site page
first answers (`published_at`, checked once a minute). Over the 89 most recent releases:

| What | Release to site page |
| --- | --- |
| A release on its own | 7 to 15 min, median about 9.5 |
| A burst (about 80 releases between 02:44 and 02:55) | 35 to 46 min |

The path a release takes today, with each step's cost:

| Step | Cost | Notes |
| --- | --- | --- |
| control relays `image-released` to the hub | seconds | |
| hub Deploy waits for the run ahead of it | 0 to 8 min | one `pages` concurrency group; GitHub keeps one pending run and cancels the rest (46 of 98 runs in a day) |
| hub: sweep for pending releases | 15 s | lists the releases of all 215 repositories over REST |
| hub: base image layers | 60 s, every run | `docker.io/alpine:3.24` resolves to `www.docker.com/token` and fails after the timeout, every run |
| hub: grype database restore and scan | 25 s | |
| hub: `lsio_hub.build` | 40 s | re-renders all 23,700 files of the API, every run |
| hub: `lsio_hub.generate` | 100 s | the build reports re-download every tarball without an `index.html` (and every 404) on every run, because that file is the "already fetched" marker |
| hub: upload and deploy Pages | 40 to 100 s | about 600 MB: the API (290 MB, 121 MB of it the package index) plus the unpacked reports (325 MB) |
| hub: hourly reconcile, observe and mods | 3 min, in the same queue | a release that arrives during it waits for it |
| control relays `hub-updated` to the site | seconds | |
| site Deploy | about 2 min | refresh snapshots 30 s, build 20 s, deploy 20 s; the rest is job setup |
| control sees the page | up to 60 s | it polls once a minute |

The hub's own run is 5 to 6 minutes of which about 4 are waste or work that nobody on the release path waits
for. A burst is slow because each hub run is slow and only one runs at a time.

## Principles

1. **Data about a build is made by the build.** The image build already has the image, its SBOM, the test
   results and the previous release in hand, on a runner the build needs anyway. Everything that is a
   function of one build (its diff against the previous release, the normalised package table, layer
   attribution, the vulnerability scan) is computed there, by the same code for live, PR and dev builds,
   and attached to the Release with the bundle. The hub stops deriving and starts indexing.
2. **The hot path only does what a reader is waiting for.** A release needs its own data and the fleet
   indexes that list it (catalog, builds list, changelog, stats). Stars, GHCR tags, the mods index,
   vulnerability rescans and the store repositories are refreshed on their own clock and never queue in front
   of a release.
3. **The website renders data it was not built with.** A build page is a view of one JSON document. The site
   is rebuilt for content (new images, docs, posts, manifest changes), not for every build: a build the site
   was not built with is rendered in the browser from the hub's data, so the hub's deploy is the last step on
   the path.
4. **No step pays for work it did on the previous run.** Every expensive input (report tarballs, base image
   layers, a registry that refuses) is fetched once and remembered, failures included.

## Target

```
image build ──┬─ arch job: build, test, syft, grype ─────────── vulns.<arch>.json
              └─ publish: tags, Release with the bundle ─────── diff.json, layers with attribution
                    │
                    ▼ build.summary
control ──── image-released ──▶ hub ingest (hot): fetch the precomputed assets of every pending release,
                                 render that image's routes and the fleet indexes, deploy Pages
                                     │
                                     ▼  the build's data is on the hub
site page for the build ◀─────── rendered from the hub's JSON in the browser when the static site predates it
                                     │
hub refresh (cold, hourly) ──────── reconcile, observe, mods, vulnerability rescans, stores
site rebuild (coalesced) ────────── new images, content, static pages for builds that arrived since
```

Expected, once all phases are in: a release on its own reaches its page in 2 to 3 minutes (one hub run, mostly
the Pages deploy). A burst of 80 is picked up by the next run or two and lands in under 10 minutes.

## What was built (2026-10-26)

### 1. A fast hub hot path (hub)

- Docker Hub base images resolve (`registry-1.docker.io`, tokens from `auth.docker.io`). A base lookup that
  fails is remembered in `data/status/bases.json` and retried a day later.
- Report tarballs are fetched once. The old "already fetched" marker was the unpacked `index.html`, which the
  keep rule then deleted on the next run, so every other deploy downloaded every report again and the hub served
  those reports as 404 in between. Each unpacked `<arch>/` now carries a `fetched.json` and is kept until its build
  rotates out.
- Every run reconciles the whole organisation over GraphQL: repositories, the newest 30 releases of each, and
  every `image.yml`, in batched queries run eight at a time. About 15 seconds, against 136 for the old REST
  reconcile (486 calls). The hourly scheduled reconcile is gone; every Deploy does it.
- `deploy.yml` is the release path only. `refresh.yml` (hourly, and dispatched by control) runs observe, the
  grype rescans and the mods index, commits, and asks for a Deploy. `data/status.json` became one file per writer
  under `data/status/`, so the two commit at the same time without conflicts.
- The API renders on every core (`BUILD_WORKERS`, 38 s to 18 s locally) while the generators run beside it, and
  the cache pruning runs beside the Pages deploy.

### 2. Per-build data from the build (builder, workflows, hub)

- `builder.derive` holds the package normaliser, the diff engine, the grype runner and its stored form, and the
  base registry lookup. The hub imports them, so there is one implementation.
- The publish job's `record` step (`builder record`) writes `record.json`: package tables, the diff against the
  newest release of the branch that is not this commit (next-tag's `diff_base`), a grype scan of both
  architectures against one database (cached per repository per day), the base image's layers, the layers and
  the test reports. It takes 35 s with a cached database and about 95 s without one, and never fails a build.
- The hub ingests a release from `build.json` and `record.json`: two small downloads, nothing derived. A part
  the record lacks is derived as before. The rescan ledger takes the build's own scan as its first entry, so a
  fresh build is not scanned twice.

### 3. The site renders new builds from the hub (site, control)

- The build page's static parts are React components (`site/src/components/build/BuildParts.tsx`) fed by one
  model (`site/src/lib/build-page.ts`). The static page renders them at build time; its 478 pages came out
  identical to the previous ones in text, links, ids and labels.
- The 404 page mounts `LiveBuildPage` for `/images/<name>/builds/<tag>/` of a known image: it reads the build's
  documents from the hub and renders the same parts and islands. Release notes show as plain text there until
  the site's next build renders them, because the Markdown renderer has no browser build short of a 3 MB WASI
  runtime.
- Fleet lists link a build control has seen go live, not only the ones the site was built with, and image pages
  list the builds the hub has that the page was built without (`NewerBuilds`).
- Control's Discord hold releases as soon as the hub serves the build, checked every 20 seconds.

### Also fixed on the way

- Control heals a job whose completion webhook never arrived: when a run completes, and once at start, it rereads
  the jobs of every completed run that still holds an unfinished job (the dangling
  `publish-stores (runtipi)` of hub run 40323844865).

### Measured after

The first release through the finished path, `shotcut v26.9.27-ls2`: released 14:35:40, its `build.summary` at
control 14:35:45, ingested from its `record.json` at 14:36:33 (with its own grype scan), its page live at
14:38:28, while the static site had not rebuilt yet. **2.7 minutes, against a median of 9.5 before.** The hub
Deploy on the new code takes about 3.5 minutes from dispatch to done: reconcile 28 s, render and generate 50 s,
upload 18 s, and GitHub's `deploy-pages` about 70 s, now the largest single step. The image build's publish
job is 35 s longer for the record (about 95 s when grype's database is not yet cached that day).

### Still open

- The hub renders all 23,700 files every run. Every response carries the fleet's `last_updated`, so reusing the
  previous run's files needs that field handled first (per-file dates, or patching it).
- Stores stay in the hub. They are a function of `image.yml` across the fleet, nobody waits for them, and store
  clients poll daily; rendering them per build would only multiply where the generators run.

## One job per Deploy (2026-10-27)

During the base-image cascade of 2026-10-26 (19:33 to 21:18, all 20 runner slots taken), the path's hub and site
steps waited for runners, not for work. The hub's Deploy was six jobs (build, deploy, prune-caches and three
publish-stores) and the site's two, and each job queued for a slot separately: a hub `deploy` job waited up to
22 minutes after its `build` had finished, the site's up to 12. `github-runners.md` has the measurement.

- The hub's Deploy is one job (hub c169ba7): ingest, render, upload and `deploy-pages`, then the cache pruning,
  which cannot fail the run. The pages go live before the build-report cache is saved, not after.
- The Unraid, Umbrel and Runtipi store repositories are pushed at the end of the hourly `refresh.yml`, as the
  target above has it, not by three jobs after every Deploy. The Pages copy of every store is still rendered by
  every Deploy.
- The site's Deploy is one job (site fcbf573).

A lone release is as fast as before (heimdall: hub 3.1 minutes, static page 5.3, against medians of 3.3 and 6.0).
In a burst each hub run now waits for one slot instead of two, and a hub plus site pair is two jobs instead of eight.

## Decisions this changed

- "The hub runs grype on new builds in the run that ingests them" became: the build scans itself; the hub
  rescans on the database's clock.
- Release notes are still sanitised to the same allowlist where they are rendered; a live page shows them as
  plain text.
- New: data about a build is made by the build; the release path never waits for slow work; the site renders a
  build it predates from the hub. See DECISIONS.md, "Hub and site".
