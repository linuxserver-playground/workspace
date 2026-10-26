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

webstation was still building when this was measured. Almost everything else is a 3 to 10 minute build per arch.

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
