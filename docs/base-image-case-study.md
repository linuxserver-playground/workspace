# Case study: moving the fleet to the playground base images

Status: run on 2026-10-26, 01:52 to 03:26 UTC. All 118 branches built green and were released. Four fixes
came out of it, one each in workflows and the hub and two in control (see [Fixes it led to](#fixes-it-led-to)).
The rest of the fleet followed the same day, 19:32 to 21:30 UTC: 133 of 134 branches green and released, none
failed (see [Follow-up: the rest of the fleet](#follow-up-the-rest-of-the-fleet)).

## Goal

Switch about 100 images in one go from `ghcr.io/linuxserver/baseimage-*` to the playground's own
`ghcr.io/linuxserver-playground/baseimage-*`, one commit per live branch, all pushed together. Then see what
overloads, if anything:

- runner queueing;
- GHCR pulls and pushes;
- control's `/events` and the Discord hold;
- the hub sweep and grype;
- the site rebuilds.

## Which images

Only normal user-facing apps whose builds are not heavyweight. Left out:

- webstation, lm-studio, kali-linux, eden and dolphin, and anything that compiles heavily (ffmpeg);
- the base images themselves, and the six internal build layers (build-agent, d2-builder, lsio-api, unrar, xvfb,
  yq);
- python, kimai and planka, which were switched first as the trial;
- any branch that was not green before the switch, whose slowest arch job took 15 minutes or more, or whose base
  tag the playground does not publish.

That left 183 images. A seeded random sample (`random.Random(20261026)`) took 100 of them, with all their live
branches: **118 branches**, 17 of them amd64 only, so 219 arch jobs. By base: selkies 48, alpine 37,
alpine-nginx 9, ubuntu 9, debian 1 (an image with several branches can count twice). Their slowest arch job
before the switch: median 5.3 minutes, maximum 10.7.

## Method

For each branch, every `FROM ghcr.io/linuxserver/baseimage-<base>:<tag>` in `Dockerfile` and
`Dockerfile.aarch64` was rewritten to the playground image, but only where the playground has that exact tag (the
`arm64v8-` tags included). Then `builder check`, and one commit, `Build on the playground base images`.

All 118 commits were pushed within ten seconds, 01:52:18 to 01:52:28 UTC, and every push started a Build run.
While the runs drained:

- control's `/api/queue.json` was sampled every 30 seconds;
- n97, the playground's control server, was sampled every minute over SSH, read-only: load, memory,
  `docker stats` for the control container and the size of `control.db`;
- afterwards, job timings came from the Actions API, hub and site runs from `gh run list`, publication times from
  control's log, and the hub's ingestion was checked against every new GitHub Release.

The trial on python (alpine324 and ha), kimai and planka, earlier the same day, had built green. The hub's
staleness view already understands base images that are in the fleet, so the switch needed no hub change.

## Results

### Runners

| What | Value |
| --- | --- |
| Outcome | 118 of 118 green; one needed a rerun (prowlarr `nightly`, GHCR, below) |
| Concurrency | 20 of 20 jobs in use from 01:52:39 to 02:50:54, 59 minutes at the cap |
| Queue drained | last case-study job finished at 02:54:37, 62 minutes after the push |
| Job-minutes | 1,090: arch jobs 910, publish 135, prepare 45 |
| Arch job | median 4.0 min, p90 6.9, max 11.9 |
| Wait, push to prepare starting | median 3.2 min, p90 13.4, max 28.9 |
| Wait, push to first arch job starting | median 20.7 min, p90 43.3, max 54.0 |
| Push to last job of the run | median 52.0 min, p90 59.1, max 62.2 |

- **The 20-job cap is the limit, and it was used well.** 1,090 job-minutes over 20 slots is 54.5 minutes of
  perfect packing; the queue drained in 62, with eden, webstation (until cancelled), the hub and the site holding
  slots too.
- **Build times did not change.** Per image, the slowest arch job's median ratio to its last build on the
  LinuxServer base was 0.98. Three were 2 to 3 minutes slower (pidgin, luanti, vscodium), within normal
  variation for a run that downloads its packages.
- **A run waits, then queues again.** A run's prepare job, then its arch jobs, then its publish job each go back
  into the queue. Under a burst, a 4-minute build took 52 minutes from push to release. GitHub schedules jobs
  roughly in order of arrival, so nothing starved, but a live release pushed in the middle of a burst waits behind
  it. The scheduler's hourly checks spread the steady-state load; a manual mass push or dispatch does not.

### GHCR

No 429s, no rate-limit retries. One failure: prowlarr `nightly`'s arm64 job pushed its staging image and the
`docker pull` straight after got `manifest unknown` from GHCR. `retry_ghcr` retried only rate limits, so the job
failed. A rerun passed. That is a read-after-write delay at the registry, so it is fixed in the pipeline rather
than left to reruns.

### Control and n97

| What | Before | During the burst |
| --- | --- | --- |
| Load average (4 cores) | 0.04 to 0.16 | at most 0.74 (1 min), 0.41 (5 min) |
| Host memory used | 1.3 GB of 15.4 GB | at most 1.3 GB |
| Control container CPU | 20% of a core at the first sample | median 2.3%, peak 48% |
| Control container memory | 74 MiB | at most 90 MiB |
| `control.db` | 604 MB | 711 MB an hour later |

Control took every webhook and `/events` post of the burst without effort. The only thing that grew was the
database: the `deliveries` table, every webhook stored whole so handlers can be replayed, is 674 MB of the 711
for about 38,000 deliveries (18 KB each). Nothing prunes it. At this rate a busy day adds about a gigabyte, so it
needs a retention window before production (open, below).

The scheduler kept working through the burst, and it showed one problem. Its release check dispatches an initial
build for any live branch without a Release, and repeated that every time the two-hour cooldown ran out,
however the last attempt ended. baseimage-kasmvnc, broken upstream, was dispatched at 21:27, 00:26 and 02:26.
webstation, which a maintainer had cancelled as too heavy, was dispatched again at 01:52 (cancelled by hand) and
would have been again at 03:52. The weekly package checks also landed during the window as they are spread over
the week: qbittorrent and gimp found new package lists (their base had just changed) and dispatched a second
release each. That is by design: `package_versions.txt` is only committed by the package check.

### Hub

Every Deploy run sweeps for all the releases it does not hold yet, and GitHub keeps only one pending run in the
`pages` concurrency group. Between 02:08 and 03:12, 119 Deploy runs were created (the burst's `image-released`
dispatches and one hourly refresh); four of them did the work and the others were dropped from the queue. That is the design (DECISIONS), and nothing was lost: 116 of the
118 releases were in `data/` by 03:21. The other two, the prowlarr `nightly` rerun and a qbittorrent package
build, came after that sweep and went to the next run.

| Deploy run | Started | Took | New SBOMs scanned | Scan |
| --- | --- | --- | --- | --- |
| 1 | 02:08 | 18 min (mostly queued behind the run before) | 4 | 1.1 min |
| 2 | 02:25 | 12 min | 17 | 1.5 min |
| 3 | 02:36 | 22 min | 66 | 12.4 min |
| 4 | 02:54 | 31 min | 128 | 19.2 min |

Ingest took 1 to 3 minutes per run and the API build about 3. **grype was the bottleneck**: one SBOM at a time,
about 9 to 11 s each, so the scan grew with the burst while everything else stayed flat.

### Site and the Discord hold

The site rebuilt after each hub deploy (control relays `hub-updated`), taking 2 to 9 minutes, and every deploy
succeeded. Control's publication watcher held each release's Discord message at "passed, publishing" until its
page answered:

| What | Value |
| --- | --- |
| Release to site page | median 35 min, p90 42, max 45, min 17 (115 releases live by 03:26) |
| Past the 30-minute deadline | 74 of 115 |

Every one of those 74 got its own Discord warning post, nearly all of them before the grouping fix below shipped.
The hold itself worked as intended: no message linked a page that did not exist yet, and each turned into its
final form when the page appeared. What failed was the time budget. Of the 35 minutes, about 20 were the hub's
serial scan.

## Fixes it led to

| Repo | Commit | Problem | Fix |
| --- | --- | --- | --- |
| workflows (`v1`) | e0eab6a | GHCR answered `manifest unknown` to the pull right after a push it had accepted, and `retry_ghcr` gave up at once | `retry_ghcr` takes an extra pattern (`RETRY_ALSO`); the post-push pull retries `manifest unknown` with the usual backoff |
| hub | 32e80c1 | grype scanned one SBOM at a time, about 11 s each, so a hub run with 66 new SBOMs spent 12 of its 22 minutes scanning, and the releases behind it missed the 30-minute publication deadline | scans run four at a time (`VULNS_WORKERS`). Measured locally with the pinned grype 0.121.0 on eight real SBOMs: 47 s serial, 19 s parallel, identical matches; 150 MB per process |
| control | d628874 | every release that missed the deadline got its own Discord warning; a burst produced one post per release | releases that cross the deadline (or reach the site after it, or expire) in the same check for the same reason share one post, split only at Discord's 2,000-character limit |
| control | a8fede4 | a branch without a Release was rebuilt every two hours however its last build ended, so a broken or cancelled image kept coming back | when the newest run built the current head and failed or was cancelled, the initial build is retried after 24 hours; a new commit or a member dispatch still builds at once |

What the fixes were shown to do: the workflows retry and the scheduler backoff are covered by tests; the
parallel scan by the local measurement above. None of them has been through a burst yet, so the next bulk change
is the test. At four workers, run 4's 19-minute scan becomes about 5, which would have kept most of the burst
under the 30-minute deadline.

## Open

- **Retention for `deliveries`.** Keep the raw payloads for a window (30 days, say) and rely on the backfill from
  GitHub for anything older, or keep them compressed. It is a design choice (the replay), so it waits on the
  maintainers.
- **Pacing mass pushes.** Pushing 118 branches at once held all 20 slots for an hour. Any live release in that
  hour would have waited up to an hour too. A bulk change should go out in batches that leave slots free, or a
  member action could stagger the dispatches. The follow-up, 134 branches with the heavy images, held them for
  105 minutes.
- **Images without a Release keep failing quietly.** baseimage-kasmvnc and webstation now retry daily rather
  than every two hours, but a skip flag on the site is the way to park one deliberately.

## Follow-up: the rest of the fleet

Run on 2026-10-26, 19:32 to 21:30 UTC, after the four fixes above had shipped. It was also their first burst.

### Scope and method

Every live branch still on `ghcr.io/linuxserver/baseimage-*` was switched in one go, without batching. That
included what the first run left out: the heavy images (ffmpeg, webstation, eden, lm-studio, kali-linux,
dolphin), the internal tools (build-agent, d2-builder, lsio-api, unrar, xvfb, yq), and the base images built on
other base images (baseimage-selkies on alpine and debian, baseimage-alpine-nginx on alpine). The method was the
same: rewrite each `FROM` whose exact tag the playground publishes, run `builder check`, and make one commit,
`Build on the playground base images`.

That came to **134 branches of 96 repos**, 23 of them amd64 only. By base: selkies 67, alpine 36, ubuntu 17,
alpine-nginx 13, debian 1. They were pushed from 19:32:36 to 19:32:49 UTC, and every push started a Build run.

Left out:

- **Branches failing before the switch:** baseimage-kasmvnc, davos, github-desktop, intellij-idea and manyfold.
  None of them has a Release, and for a branch without one the scheduler's release check builds a new head at
  once (a8fede4, above). So a `[skip ci]` commit would still have been built a few minutes later, and they were
  left untouched. To park a branch, leave it alone or set a skip flag.
- **Base tags the playground does not publish:** `baseimage-alpine:3.20` (habridge, htpcmanager, tvheadend),
  `baseimage-alpine-nginx:3.20` (diskover) and `baseimage-selkies:ubuntunoble` (calibre `v4`).

docker-xvfb was deleted from the organisation while its run was queued, so its result cannot be read.

### Results

| What | Value |
| --- | --- |
| Outcome | 133 of 133 readable runs green, no reruns, no failed jobs |
| Concurrency | 20 of 20 from 19:33 to 21:18, 105 minutes at the cap; queue peak 183 jobs (19:40) |
| Queue drained | last job finished at 21:27:03, 114.5 minutes after the push |
| Job-minutes | 1,966: arch jobs 1,527 (243 jobs), publish 383, prepare 55 |
| Arch job | median 4.7 min, p90 9.4, max 78.3 (ffmpeg amd64) |
| Wait, push to first arch job starting | median 27.9 min, p90 83.3, max 99.7 |
| Push to last job of the run | median 73.7 min, p90 106.9, max 114.5 |
| GHCR | no 429s, no `manifest unknown`, not one `retry_ghcr` retry in 509 job logs |
| Release to the hub serving it | median 11.3 min, p90 17.6, max 34.1; 2 of 133 past 30 minutes |
| Live on the website | all 133: the hub serves every build and the site has every static page |

- **The heavy images set the tail.** Nine arch jobs from seven images (ffmpeg, webstation, eden, lm-studio,
  kali-linux, azahar, dolphin) took 378 job-minutes, a fifth of the total. Each held a slot for 27 to 78 minutes.
- **Publish jobs queue behind newer arch jobs.** A Publish job enters the queue only when its arch jobs finish,
  and GitHub serves the queue roughly in order of arrival. At 20:23, 57 of the 139 queued jobs were Publish jobs
  of images that were already built and tested.
- **Publish takes 2.9 minutes now** (median), up from about 1.1 in the first run. Most of it is
  `Derive record.json` (median 88 s, max 149), the build-side grype scan that DECISIONS accepts. The longest
  single step was lm-studio's `Publish tags`: GHCR took 4 minutes to copy its layers from `build/` into the
  released repo.
- **The fixes held.** The `manifest unknown` retry never fired. The hub no longer scans during a burst, because
  every build brings its own record: Deploy's `build` job (ingest and render) took 1.5 to 3.5 minutes, and ingest
  at most 83 s. With control treating a release as live once the hub serves it (4e02951), the median release
  reached the website in 11 minutes, against 35 in the first run, and 2 of 133 missed the 30-minute deadline,
  against 74 of 115. These times come from the hub's `data/` commits and its Deploy jobs, not from control's log.
- **The hub and site now wait for runners, not for work.** Of the 144 hub Deploy runs created, 11 did the work
  and 133 were superseded, as designed. But each Deploy is five jobs (build, deploy, prune-caches and three
  publish-stores), and each one queued separately behind the image builds:
  - the 19:52 run's `deploy` job waited 22 minutes for a slot after its `build` finished;
  - the site's Deploy waited up to 9 minutes for its `build` job and 12 for its `deploy` job, for about
    2 minutes of work.

  The two releases that missed the deadline lost their time this way.
- **Every job warns that Node.js 20 is deprecated.** 508 warnings name `actions/upload-artifact@v4`,
  `actions/download-artifact@v5`, `docker/login-action@v3`, `actions/cache@v4` and
  `actions/attest-build-provenance@v2`. GitHub forces them onto Node 24 for now. When it stops, every build
  fails at once. The current majors run on Node 24: upload-artifact v7, download-artifact v8, login-action v4,
  setup-buildx-action v4, cache v6, attest v4, checkout v7.
- The ci harness's SKIPs were all expected: tests disabled in the manifest (build-agent, d2-builder,
  faster-whisper, ffmpeg, swag, unrar, yq) or no `test.web` to screenshot. The shellcheck findings that prepare
  reports as warnings are in upstream's own scripts.

### What can be covered automatically

Nothing failed, so these are the failures this run showed coming:

| Risk | Where | Cover |
| --- | --- | --- |
| Node 20 actions stop running, and every build breaks the same day | workflows (and every repo's own workflows) | Bump to the Node 24 majors above, check each one's breaking changes (artifact actions especially), prove it with a heimdall build, move `v1` |
| A release misses the Discord deadline because the hub's and site's deploy jobs queue behind builds | hub `deploy.yml`, site deploy | Fewer jobs on the release path: deploy in the same job as build, and stores in their own run or in `refresh.yml`, so a burst costs one wait instead of two or three |
| Publish jobs of finished images wait behind newer arch jobs | GitHub's queue | Pace bulk changes (Open, above), or have the scheduler stagger a member's mass dispatch |
| A switch reaches a branch whose base tag is not published | migration scripts | Check the tag exists before rewriting, as this run did; publish 3.20 and `ubuntunoble`, or retire those branches |

### Still on LinuxServer images

- The five failing branches and the five whose base tag is missing (above).
- 48 `FROM ghcr.io/linuxserver/unrar` stages in 15 repos. The playground publishes `unrar:latest` and
  `unrar:arm64v8-latest`, so the same rewrite applies.
- tvheadend's `ghcr.io/linuxserver/picons-builder`, which has no playground repo.

These are the last references outside the playground namespace apart from the base images that AGENTS.md
allows.
