---
description: Force a full hub refresh and follow it through to the site
---
1. `gh workflow run deploy.yml -R linuxserver-playground/hub`, then watch the run to the end.
2. Control relays `hub-updated` to the site after a successful Deploy. Confirm a site deploy started within a
   few minutes of it, and watch that run too.
3. Report both outcomes with run links. On a failure, show the failing step's log tail.

Control already dispatches this refresh every hour, so only force one when you need fresh data now.
