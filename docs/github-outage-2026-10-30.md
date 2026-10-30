# GitHub's outage of 2026-10-30: what the fleet missed, and what changed

On 2026-10-30 from about 17:50 UTC GitHub ran an incident on Actions, Webhooks and Pages ("delays affecting
Actions workflows, Pages deployments, and webhook events"). The playground was under its normal load plus a
fleet-wide push (the release asset checks), so this was the first real test of control's self-healing with
GitHub itself degraded. This is what was observed over the first hour, hole by hole, and what was changed in
the same session. Read it with `build-failure-triage.md`: that one is about a red build, this one is about the
plumbing around it.

## What was observed

| Where | Symptom | Cause |
| --- | --- | --- |
| control `/status` | Backfill ended with `502 Bad Gateway` after two minutes, `counts: null` | One 502 from one run's jobs endpoint raised out of the whole pass; no retry on 5xx |
| control `/status` | Reconcile's `runs` step ended with the same 502 after redelivering 6 lost webhooks; `threads` still ran | Same client; the step read every unfinished run in one loop with no per-run isolation |
| control fleet board | docker-ombi's run showed `queued` for two minutes after GitHub had it `completed success` | Its `workflow_run completed` and job webhooks were lost; a heal is triggered only when some other run completes, which under load happened within two minutes (quiet hours would have waited for the 30-minute reconcile, which had just died on the 502) |
| site Deploy | Two runs failed at 17:10 and 17:16 in `Refresh data snapshots from the hub`: `404 for …/catalog/<image>/builds/<tag>.json` | The hub's Pages deploy was still rolling out: its index listed the build, the record file was not served yet. The refresh raised on the 404 and the whole Deploy failed |
| control `/api/batch.json` | `free: -4` with 10 jobs running; `batch: {proot-apps: 12}` while the proot-apps push build ran 4 wide | The width of control's last dispatch (12, the 00:00 package check) was applied to any later run of the project, a push run included |
| control runs page | The hub's Deploy flagged `stuck` at 273 s against a p95 threshold of 116 s | Pages was slow; the p95 of normal times is the wrong yardstick during an incident. Display only, nothing acts on it |
| hub | 14 `image-released` Deploys cancelled in 40 minutes, each after 10 to 16 minutes queued | By design: one pending run per concurrency group, every run reconciles the whole org. Nothing was lost, but each cancelled run had held a runner slot request for the queue time |
| docker-tvheadend | A live build failed on arm64 with `no match for platform in manifest`, and GitHub's own jobs API listed no failed step | Degraded API. Control's fallback for "failed job, no failed step" is "the runner was lost" and it queued a re-run. Harmless, one wasted build; the real cause looked like upstream's `picons-builder` manifest, not GitHub |
| scheduler | One `release` check for xvfb recorded `error`: `404 Not Found` for `branches/master` | Degraded API answering 404 for a branch that exists; the next hourly check succeeded |

What worked without help: redelivery of lost webhooks (6 in one pass), the Discord hold on releases (nothing
linked a 404), the one-time re-run of an infrastructure failure (sabnzbd's `Download manifest`), and the
`image-released` dispatch to the hub.

## What changed

- **Control's GitHub client retries reads** after a 502, 503, 504 or a dropped connection: three attempts, 1 s then
  4 s apart (`control/github.py`, and the backfill's own client). Writes are never retried: a dispatch that answered
  502 may still have happened.
- **Reconcile isolates each run.** One run GitHub cannot answer for is logged and summarised in the pass's `errors`;
  the others are still read. A pass that redelivered anything or hit an error is followed by another after 5
  minutes instead of 30 (`RECONCILE_RETRY`), because that is exactly when GitHub is dropping things.
- **Heal runs from the scheduler's loop every 5 minutes** (`heal.tick`), not only when some other run completes, so a
  lost completion in a quiet hour is repaired in minutes.
- **The site's refresh skips a build whose record the hub does not serve yet** (`scripts/refresh-data.mjs`), says
  how many it skipped, and leaves them for the next run. The Deploy no longer fails on a hub deploy still rolling
  out.
- **Batch capacity sizes a push or cron run at the workflow default.** Only a `workflow_dispatch` run created after
  control's last dispatch carries that dispatch's width (`control/batch.py`).

## Left as it is, on purpose

- The hub's cancelled Deploys. Each run reconciles the whole org, so the newest pending run is all that is needed.
- The `stuck` flag's p95 threshold. It is a hint on the runs page, nothing acts on it, and a threshold that widened
  during incidents would hide real stalls later.
- Control's "the runner was lost" re-run when GitHub reports a failed job with no failed step. One re-run at most,
  and the alternative (never re-running a job GitHub describes badly) would miss the real lost-runner case.
- Pages propagation lag between the hub's index and its files. The site tolerates it now; making the hub's deploy
  atomic is not possible on Pages.

## How to watch the next one

```bash
curl -s https://www.githubstatus.com/api/v2/incidents/unresolved.json | jq '.incidents[] | {name, status}'
curl -s https://ci.thelamer.duckdns.org:8443/api/status.json | jq '{last_reconcile, last_backfill, healing}'
curl -s https://ci.thelamer.duckdns.org:8443/api/runs.json | jq '[.active[] | {repo: .run.repo, status: .run.status, stuck}]'
curl -s https://ci.thelamer.duckdns.org:8443/api/batch.json | jq .capacity
```

Compare `/api/runs.json` against `gh run view` for a run or two: a run control shows unfinished that GitHub shows
completed is a lost webhook, and the time until it corrects itself is the number that matters.
