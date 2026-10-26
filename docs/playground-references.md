# Playground references to swap back

The playground builds on its own images so that it is isolated from `linuxserver`: nothing it builds pulls
from `ghcr.io/linuxserver/`. These rewrites exist only for the playground. When the v2 layout moves to the real
`linuxserver` org, swap every one back to the `ghcr.io/linuxserver/` name, or drop the commit. Upstream's
Dockerfiles never had these changes.

Each rewrite changes only the registry path of a `FROM` line in `Dockerfile` and `Dockerfile.aarch64`. The tag
is unchanged, and so is the rest of the Dockerfile. Every one is a single commit with a fixed subject, so the
commits can be found and reverted mechanically.

## Base images

Commit subject: `Build on the playground base images`. Rewrites
`ghcr.io/linuxserver/baseimage-<base>:<tag>` to `ghcr.io/linuxserver-playground/baseimage-<base>:<tag>`.

- **Trial:** python, kimai and planka.
- **First batch:** 118 branches from [the case study](base-image-case-study.md).
- **Follow-up:** 134 branches, the rest of the fleet. Among them, two base images build on other playground
  base images: baseimage-selkies (on alpine and debian) and baseimage-alpine-nginx (on alpine).

Every live branch is now on the playground bases except:

| Repo | Branch | Why |
| --- | --- | --- |
| baseimage-kasmvnc, davos, github-desktop, intellij-idea, manyfold | default | failing before the switch, left untouched |
| habridge, htpcmanager, tvheadend | master | `baseimage-alpine:3.20` is not published in the playground |
| diskover | master | `baseimage-alpine-nginx:3.20` is not published in the playground |
| calibre | `v4` | `baseimage-selkies:ubuntunoble` is not published in the playground |

## unrar

Commit subject: `Copy unrar from the playground image`. Rewrites `FROM ghcr.io/linuxserver/unrar:latest AS unrar`
and `:arm64v8-latest` to `ghcr.io/linuxserver-playground/unrar`. 24 branches of 14 repos:

| Repo | Branches |
| --- | --- |
| docker-bazarr | `development`, `master` |
| docker-calibre-web | `master`, `nightly` |
| docker-deluge | `libtorrentv1`, `master` |
| docker-flexget | `main` |
| docker-lazylibrarian | `master` |
| docker-medusa | `master` |
| docker-mylar3 | `master`, `nightly` |
| docker-nzbget | `master`, `testing` |
| docker-plex | `master` |
| docker-pyload-ng | `develop`, `main` |
| docker-qbittorrent | `libtorrentv1`, `master` |
| docker-sabnzbd | `master`, `nightly`, `unstable` |
| docker-sickgear | `develop`, `master` |
| docker-transmission | `master` |

sabnzbd's `Dockerfile.riscv64` still names `ghcr.io/linuxserver/unrar:riscv64-latest`. riscv64 is out of scope
and that file is never built, so it was left as upstream has it.

## Still pointing at linuxserver

- tvheadend's `ghcr.io/linuxserver/picons-builder` stage: the playground has no picons-builder repo.
- The images in the base-image exceptions above.
- selkies-layers and proot-apps are not in the playground namespace yet. Leave references to them as they are
  until they are.

## Finding and swapping them back

To list every remaining reference on a branch, run this in a clone:

```bash
git grep -n 'ghcr.io/linuxserver-playground/' origin/<branch> -- 'Dockerfile*'
```

To swap a branch back, either revert its commit or run the reverse rewrite:

```bash
sed -i -E 's#^(\s*FROM\s+)ghcr.io/linuxserver-playground/#\1ghcr.io/linuxserver/#' Dockerfile Dockerfile.aarch64
```

Then run `builder check` as for any change.
