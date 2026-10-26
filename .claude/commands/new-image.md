---
description: Convert a linuxserver/docker-<name> image to the v2 layout in the playground
argument-hint: <name, e.g. sabnzbd>
---
Convert `linuxserver/docker-$ARGUMENTS` into `linuxserver-playground/docker-$ARGUMENTS`, following the "New
image" recipe in AGENTS.md and the conversions in `docs/conversion-report.md`.

1. Check that `linuxserver-playground/docker-$ARGUMENTS` does not exist yet. If it does, stop and report what is there.
2. Clone the original into `reference/docker-$ARGUMENTS` and list its live branches (from `jenkins-vars.yml` on
   each branch).
3. On each live branch that readme-vars does not mark deprecated: `builder migrate`, then resolve every TODO
   it prints. Prefer typed version and notes sources over `command`. Then run `builder render` and
   `builder check` (both must say ok), delete `Jenkinsfile`, `jenkins-vars.yml`, `readme-vars.yml` and the old
   `.github/`, and make the one conversion commit.
4. Build and run it locally as the image repo's AGENTS.md describes, if Docker is available. Say plainly if
   it is not.
5. Create the playground repo (public) and push only the converted live branches, with history, default branch
   first.
6. GitHub runs a workflow for only one of a new repo's first pushes: dispatch the branches that got no run.
   Watch every first build to the end (`gh run watch`).
7. Finish with the Release link and the site image page (control finds the repo on its first push; the GHCR
   package is created public). Add a row to `docs/conversion-report.md` with anything unusual.
