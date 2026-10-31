# One build per release: the package check and the package table

Written 2026-10-31, when the two-build package check was replaced. This is how a live build decides to release,
how `package_versions.txt` is kept current without a second build, and how the build page explains the result.

## What Jenkins did, and the playground until 2026-10-31

The weekly package check built the image, compared the fresh package list with the committed
`package_versions.txt`, committed the new list when it differed, and let that push start a normal build. Two
full multi-arch builds for one release, and one full build for a check that found nothing. The release build
of an upstream version or a push never touched the table, so between checks the committed table lagged the
released image by days: the compare link on firefox ls5's page showed firefox moving 158 → 159 four days after
that had shipped, because the table in git was from the previous check.

## What happens now

Every live build runs the same job graph: prepare, build and test per architecture, publish. The publish job
(`workflows/.github/workflows/image-build.yml`) does this, in order:

1. **Check out the live branch** (`Check out repository (live)`), for the two table steps below.
2. **Compare the package table**, only for `reason: packages`: `package-check compare` reads the fresh
   `package_versions.amd64.txt` the ci harness wrote and the committed `package_versions.txt` at the built
   commit, and compares their md5 with trailing whitespace normalised (arm64 is compared with the previous
   release's asset for the summary only).
3. **Decide** (`gate`): `skip` is true for a package check that found no change; `release` is true for a green
   build that pushes images and is not skipped. A skipped run publishes nothing, releases nothing, reports
   `result: skipped` to the control plane and stays quiet on Discord.
4. **Publish, record, release** when `release` is true, as any build: the tags from the staging references, the
   provenance attestation, `build.json`, `record.json` (`builder record`, which now also lists the commits between
   this build and the previous release, see below), the GitHub Release with its assets, then Pages.
5. **Commit the package table** after a successful release, every live build: `package-check commit` puts the
   fresh amd64 table on the live branch as `Update package versions [skip ci]` when the branch's table differs
   (fetch, rebase, push, three attempts). A push that still fails is a warning, not a failure: the release is out
   and the next one commits the table. The step runs after the release so a failed release never leaves a
   table commit that would hide an unreleased head.

So a package check that finds changes releases from its own run, and an upstream or push build that also moved
packages commits the table itself. There is no second build, ever.

## The build number

A package check runs on the released commit, or on it plus the table commit its release made. `next-tag`
(`workflows/scripts/next_tag.py`) looks through the pipeline's own `[skip ci]` commits (`Update package
versions`, `Update generated files`) when it reads the tags at HEAD, so a `rebuild` or `manual` run from there
is a rebuild of the released commit and republishes the same `-lsN`, as before. A `packages` run must not do
that: the Prepare job passes `fresh: true` to `next-tag` for `reason: packages`, which ignores the head tags, so a
check that found changes releases `-ls<N+1>` and its record diffs against `N`.

## Why nothing rebuilds after the table commit

Control's release check (`control/control/scheduler.py`) dispatches a `rebuild` when the branch head is not
the commit the newest Release points at, unless the head's subject carries `[skip ci]` and GitHub's compare
between the two shows only files the build commits itself. `package_versions.txt` is on that list
(`GENERATED_FILES`) with README, AGENTS.md, LICENSE, FUNDING.yml, `root/donate.txt` and the two workflows.
Any other file in the range means a release is owed.

## What the build page says

`record.json`'s diff (contracts 1.15, `builder/builder/derive/commits.py`) carries the commits between the
previous release's commit and this one, from GitHub's compare (the record action fetches it; the hub fetches it
for a release it derives itself): sha, subject, author, whether the pipeline made it, and the areas the range
touched: `image.yml`, the Dockerfiles, `root/`, generated files, the package table, other. The first three can
change the image; the rest never do, so a push whose commits touch only generated files is no longer classed as
a LinuxServer change.

The site composes the "Why this built" panel at the top of every build page from three things
(`site/src/lib/why.ts`):

- **the trigger**, build.json `reason`: a push, the hourly upstream check (with the upstream move linked: the
  compare between two shas for a commit-sourced version, else the release), the weekly package check, the
  release check or a requested rebuild, a manual dispatch;
- **the diff**: the upstream move, the base image rebuild (linked to the base build, with the share of this
  build's package changes that the base builds in between carry in their own diffs), the Dockerfile, the package
  counts per architecture;
- **the commits**, listed newest first with the pipeline's own marked, and one sentence saying what they touched
  and whether anything reaches the image.

The same code renders the static page and the live page a build gets before the site rebuilds.

## Where the pieces are

| Piece | Where |
| --- | --- |
| Compare and commit steps | `workflows/.github/actions/package-check/` (`package_check.sh compare` and `commit`) |
| The publish job's order and gate | `workflows/.github/workflows/image-build.yml`, job `publish` |
| Build number through own commits, `--fresh` | `workflows/scripts/next_tag.py`, `workflows/.github/actions/next-tag/` |
| Compare fetch for the record | `workflows/.github/actions/record/action.yml` |
| Commit list and areas | `builder/builder/derive/commits.py`, read by `derive/diff.py`; `schemas/record.schema.json` `diff.commit` |
| Release check allowance | `control/control/scheduler.py` `GENERATED_FILES` |
| Hub pass-through and derive-time fetch | `hub/lsio_hub/models.py` `CommitChange`, `ingest.py` `_compare` |
| The panel | `site/src/lib/why.ts`, `site/src/components/build/BuildParts.tsx` `WhyThisBuild` |

Records made before 2026-10-31 have no commit list; their pages say so and link GitHub's compare. Builds the
old check dispatched carry `reason: rebuild`, so their headline cannot name the check.
