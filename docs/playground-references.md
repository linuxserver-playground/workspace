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

## wheelie

Commit subject: `Install wheels from the playground wheel index`. Rewrites the pip `--find-links`
`https://wheel-index.linuxserver.io/<index>/` to `https://linuxserver-playground.github.io/wheelie/<index>/` in
`Dockerfile` and `Dockerfile.aarch64`. A smoke test of the slim wheelie, so far one branch:

| Repo | Branches | Index |
| --- | --- | --- |
| docker-sabnzbd | `master` | `alpine-3.24` |

Only the playground indexes whose legacy `wheels.linuxserver.io` entries were moved (`alpine-3.24`) are safe
to point at; see wheelie's `scripts/migrate.py`. Every other image still uses `wheel-index.linuxserver.io`.
At the cutover the playground index becomes `wheel-index.linuxserver.io` again, so revert these commits.

## selkies-layers

`linuxserver-playground/selkies-layers` carries two rewrite commits of its own:
- `Build on the playground base images`: the 23 `Dockerfile.<distro>.<layer>` `FROM` lines, tags unchanged
  (`baseimage-alpine:3.24`, `-arch:latest`, `-debian:trixie`, `-debian:kali`, `-fedora:44`, `-ubuntu:resolute`).
- `Publish the layers to the playground namespace`: `LAYERS_IMAGE` in `.github/workflows/build.yml`, the
  default `IMAGE` in `scripts/matrix.py`, and `README.md`.

The six `Dockerfile.*.wtype` files still clone `https://github.com/linuxserver/waylandtyper.git` (a source
checkout; the playground has no copy).

proot-apps needs no entry: every name in it follows `GITHUB_REPOSITORY`, as upstream designed it for forks.

## Still pointing at linuxserver

- tvheadend's `ghcr.io/linuxserver/picons-builder` stage: the playground has no picons-builder repo.
- The images in the base-image exceptions above.
- Images that use `ghcr.io/linuxserver/selkies-layers`, which the playground now publishes with every tag they
  use: docker-baseimage-selkies (master, alpine324, arch, fedora44, kali, ubunturesolute, dev), docker-kali-linux,
  docker-lm-studio and docker-pelorus (master). Swapping baseimage-selkies rebuilds every selkies desktop image,
  so it waits for a planned cascade.
- The base images fetch the mod scripts (`docker-mods.v3`, `package-install.v1`, `lsiown.v1`,
  `with-contenv.v1`) from `linuxserver/docker-mods` `mod-scripts`; the playground's docker-mods has no such
  branch. Swapping them rebuilds the fleet, so it waits for a planned cascade too.

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
