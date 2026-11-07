---
description: Force a full hub refresh and follow it through to the site
---
Control dispatches the hub's and the site's Deploys itself, on fixed slots at most nine times an hour, whenever
something changed. Look at `deploys` in `https://ci.thelamer.duckdns.org:8443/api/status.json` first: a pending
request goes out at the slot it names. Only force a run when control is down or you need refreshed data now.

1. For new stars or mods data, `gh workflow run refresh.yml -R linuxserver-playground/hub` (control serves its
   `Refresh data` commit at the next slot). Otherwise `gh workflow run deploy.yml -R linuxserver-playground/hub`,
   then watch the run to the end. A hand dispatch counts against GitHub Pages' ten builds an hour.
2. When the Deploy pushed to `gh-pages`, control requests the site's next slot. Confirm a site deploy started
   within about seven minutes, and watch that run too.
3. Report both outcomes with run links. On a failure, show the failing step's log tail.
