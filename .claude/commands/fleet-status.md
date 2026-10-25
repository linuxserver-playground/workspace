---
description: Summarise the playground fleet's health from control and recent runs
---
Report the current state of the linuxserver-playground fleet. Read-only: change nothing.

1. `curl -fsS https://ci.thelamer.duckdns.org:8443/api/status.json` for control's own health (GitHub App,
   last discovery, scheduler), then `/api/fleet.json` for every live branch and its last build.
2. List failed or stuck runs across image repos in the last day (`gh run list -R linuxserver-playground/<repo>
   --status failure --limit 5` for each `docker-*` repo, plus `hub` and `site`).
3. Check that the hub's last Deploy and the site's last deploy succeeded.

Answer with a short table: branches that are red or stale (no release in a week while upstream moved), with the
failing step and a link to the run, then one line each for control, hub and site. If everything is green, say so
in one line.
