# Case study: moving the fleet to the playground base images

Status: planned, not run yet. It starts once every remaining image is staged.

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

Only builds that are not heavyweight. Leave out:

- webstation, lm-studio, kali-linux, eden and dolphin;
- any image that compiles heavily (ffmpeg, for example).

For scale, a recent successful build took 45 minutes for lm-studio, 32 for kali-linux, 30 for eden and 27 for
dolphin, against 5 for heimdall. Pick from images whose last successful build was well under that.

Also leave out:

- any branch whose base tag the playground does not publish;
- any branch that is failing for an upstream reason before the switch.

## Method

For each branch, rewrite every `FROM ghcr.io/linuxserver/baseimage-<base>:<tag>` in `Dockerfile` and
`Dockerfile.aarch64` to the playground image, but only where the playground has that exact tag (the
`arm64v8-` tags included). Then run `builder check` and make one commit, `Build on the playground base images`.

This was first tried on python (alpine324 and ha), kimai and planka on 2026-10-26, and all four built green.
The hub's staleness view already understands base images that are in the fleet, so the switch needs no hub
change.
