# Running the fleet on GitHub's free runners

The playground builds, tests and releases the whole LinuxServer.io fleet on the free GitHub-hosted runners
that public repositories get: amd64 on `ubuntu-24.04`, arm64 natively on `ubuntu-24.04-arm`, and Pages for
the hub and the site. There is no Jenkins and there are no self-hosted build agents. The only machine we run
is control, the scheduler and webhook server. This page records what that costs and where it pinches,
measured rather than guessed.

## Measured: staging the remaining fleet

The window runs from 2026-10-24 20:37 to 2026-10-26 01:13 UTC, about 29 hours. It covers every run in all
216 `docker-*` repos, which is mostly the six staging batches in `conversion-report.md` plus the fix and
rerun builds. The numbers come from the Actions API (runs and jobs).

| What | Value |
| --- | --- |
| Build runs | 525: 459 success, 57 failure, 4 cancelled, 3 skipped, 2 startup failures |
| Triggers | 364 push, 157 dispatch, 4 pull request |
| Job-minutes | about 4,900: arch jobs 4,245 (arm64 1,507), publish 456, prepare 153 |
| Run duration | median 9.8 min, p90 23.1 min, max 102 min (ffmpeg) |
| Arch job, slowest per image | median 5.2 min; 203 of 214 images under 15 min |
| Concurrent jobs | peaked at the account's cap of 20; 136 minutes at 18 or more |
| Queue, run created to first job | median 0.1 min, p90 5.4 min, max 20 min |

The heavy builds, by their slowest arch job:

| Image | Minutes |
| --- | --- |
| ffmpeg | 94 |
| webtop | 60 |
| lm-studio | 34 |
| azahar | 32 |
| kali-linux | 29 |
| eden | 28 |
| dolphin | 26 |
| digikam | 22 |

webstation (three emulators compiled from source) was cancelled before it finished and is not built. Almost
everything else is a 3 to 10 minute build per arch. `base-image-case-study.md` measures a burst of 118 of those
at once.

## What it means

- **The 20 concurrent jobs are the scarce resource, not minutes.** Public repos pay nothing for minutes. A
  burst of new repos or dispatches fills the 20 slots within minutes, and then every run queues, including a
  live release someone is waiting for. Each image takes two arch jobs at once, so 20 slots means about 10
  images building in parallel.
- **Keep everything that is not a build off the runners.** That covers registry copies, git mirroring and
  backups (DECISIONS, and workspace issues #4 and #5). One runner slot held by a slow registry is one image
  not building.
- **Spread heavy builds out.** A handful of images (the table above) take 25 to 95 minutes per arch. They
  should not be dispatched together, and bulk exercises leave them out (`base-image-case-study.md`).
- **Bursts are ours to pace.** Staging pushed 30 repos at a time and waited for each batch to finish. The
  scheduler's hourly checks spread the steady-state load; a manual mass dispatch does not, so throttle it.

## Measured: the hub and the site during a burst

On 2026-10-26 from 19:00 to 23:00 UTC, a base-image cascade rebuilt 120 repos (1,651 jobs) and held all 20
slots from 19:33 to 21:18. In those four hours the hub ran 188 jobs, second only to webtop, and the site 60. The
numbers come from the Actions API (runs and jobs).

| Hub | Runs | Jobs | Job-minutes | Queued, minutes |
| --- | --- | --- | --- | --- |
| Deploy, `image-released` from control | 25 | 150 | 88 | 220 |
| Deploy, dispatched by `refresh.yml` | 4 | 24 | 12 | 68 |
| Deploy, push | 1 | 6 | 3 | 0 |
| Refresh (4 dispatched by control, 1 cron) | 5 | 5 | 11 | 5 |
| Check, push | 3 | 3 | 6 | 3 |
| **Total** | 38 | **188** | **121** | **296** |

By job, across the 30 Deploys: `build` 30 jobs and 68 minutes, `deploy` 30 and 20, `prune-caches` 30 and 2,
`publish-stores` 90 (a matrix of three) and 14. The site ran 30 Deploys, one per successful hub Deploy
(control relays `hub-updated`), of two jobs each: 60 jobs, 61 minutes.

- **The coalescing worked.** 200 Deploy runs were created in the window and 170 of them were dropped while
  pending, before they had a job: GitHub keeps one pending run per concurrency group, and each run reconciles
  the whole organisation, so nothing was lost. While the slots were full (19:33 to 21:18) only seven Deploys ran,
  back to back. The other 23 ran after 21:18, when the slots were free and each release that arrived alone got a
  run of its own, which is what keeps a lone release fast.
- **The jobs per run did not.** Each Deploy was six jobs, five of them under a minute of work. The hub's 188 jobs
  were 121 job-minutes, on average half a slot over the four hours, but every one of them was a separate wait for
  a slot.
  In the saturated stretch the hub's 51 jobs waited 262 minutes in all: `deploy` up to 22 minutes after its
  `build`, each `publish-stores` up to 22, `prune-caches` up to 18. The site's `deploy` job waited up to 12.
  Those waits were on the release path: the Pages deploy is the last step before a build's page exists.

What changed (2026-10-27):

- The hub's Deploy is one job (hub b5f0ee3). `deploy-pages` and the cache pruning are steps after the upload, in the
  `github-pages` environment; the pruning cannot fail the run, because control relays `hub-updated` only after a
  successful one.
- The Unraid, Umbrel and Runtipi store repositories are pushed by the hourly `refresh.yml`, as the last steps of
  its one job (16 s), not by a three-job matrix after every Deploy. Store clients read them at most daily. The
  Pages copy under `/stores/<platform>/` is still rendered by every Deploy.
- The site's Deploy is one job (site d2baa95): the Pages deploy is a step of the build job.

| Same window, recounted | Before | After |
| --- | --- | --- |
| Hub jobs | 188 | 38 (30 Deploy, 5 Refresh, 3 Check) |
| Site jobs | 60 | 30 |
| Slot waits per hub release, when the slots are full | two (build, then deploy) | one |

Measured on 2026-10-27 with the new workflows, against the same shape of burst from the evening before (both with
free slots, so the counts show the jobs and not the queue):

| Burst | Releases | Hub Deploys run (dropped) | Hub jobs | Site Deploys | Site jobs | Jobs in all |
| --- | --- | --- | --- | --- | --- | --- |
| 2026-10-26 22:46 to 23:06, before | 12 | 7 (5) | 42 | 8 | 16 | 58 |
| 2026-10-27 17:07 to 17:13, after | 10 | 4 (6) | 4 | 4 | 4 | 8 |

The second burst was five empty commits to small images (librespeed, freshrss, grocy, wikijs, syslog-ng) plus five
base-image releases that happened to land in the same minutes. Each of the five reached the hub 3.1 to 4.5 minutes
after its Release. A lone release (heimdall `v2.8.3-ls4`, the same day) reached the hub in 3.1 minutes and its
static site page in 5.3, against medians of 3.3 and 6.0 over the 23 lone releases of the two days before. The Deploy
itself is unchanged at about three minutes; the gain is in a burst, where it now waits for one slot instead of two.

What was left alone, and why:

- **Coalescing `image-released` in control.** Dispatches cost nothing on the runners: GitHub already drops all but
  one pending Deploy, and while the slots were full only seven Deploys ran in 105 minutes. Holding dispatches back
  would only make a lone release wait.
- **Coalescing `hub-updated`.** The site rebuilds once per successful hub Deploy, so in a saturated stretch it ran
  as rarely as the hub did (seven times). It is no longer on the release path (the 404 page renders a new build from
  the hub), so it could be spaced out, but it was 60 job-minutes in four hours and a debounce in control saves
  little where the slots are scarce.
- **`refresh.yml` and Deploy.** They do not collide: separate concurrency groups, separate files in `data/`, and the
  Deploy that refresh asks for joins the pending one when a burst is already queuing.

Fixed: **the site's snapshot refresh was rate-limited by Pages.** Every site Deploy read every image's documents
and every build's from the hub's Pages site, about 5,000 requests with up to a hundred in flight, and gave up after
four retries (about 22 seconds). From 2026-10-27 08:17 Pages answered 429: 16 of 200 site Deploys failed, nine of
the ten newest. Pages limits by IP, so two full refreshes run by hand from one machine locked it out of every hub
URL for over half an hour. Since site `f9efc2d` the refresh fetches only the builds `src/data/builds/` lacks
(3 of 780 on the first Deploy after the fix, against 776 before), keeps at most 8 requests in flight, backs off on
429 for up to about four minutes, and refetches every build only on the daily scheduled run, in place, so a run
that fails halfway leaves a whole snapshot.

## Things the runners taught us

- **Transient failures are real but rare.** In about 525 runs we saw:
  - a GHCR token endpoint EOF;
  - a 502 from a download;
  - an Alpine CDN mirror serving an incomplete index twice in a row;
  - a uv package download failure.

  One rerun fixed each of them, except the Alpine mirror case, which built green on the next commit.
  `build-failure-triage.md` says how to tell these apart from real failures.
- **A new repo builds only one of its first pushes.** Dispatch the live branches that got no run (AGENTS.md).
- **Actions drops a job output that contains a masked value,** even by coincidence. The manifest now travels
  between jobs as an artifact for that reason (workflows `image-build.yml`).
- **Disk.** Every arch job frees disk space first (`free-disk`), and the heavy desktop images need it.
