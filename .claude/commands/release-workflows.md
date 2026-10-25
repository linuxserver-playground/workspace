---
description: Push a workflows change and move the floating v1 tag, then prove it with a build
---
In `repos/workflows`:

1. Run `./scripts/check.sh`. Stop on any failure.
2. Make sure the change is backward compatible for every caller of `@v1`: same inputs, outputs and ci
   interface. If it is not, stop and say it needs a new major tag.
3. Push main, then `git tag -f v1 && git push -f origin v1` (no confirmation needed in the playground).
4. Dispatch a build of a small, fast image (`gh workflow run build.yml -R linuxserver-playground/docker-heimdall`),
   watch it to the end, and report the outcome with the run link. If it fails because of the change, fix it
   forward or move `v1` back to the previous commit, and say which.
