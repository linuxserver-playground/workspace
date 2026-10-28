# Playground references to swap back

The playground builds on its own images so that it is isolated from `linuxserver`: nothing it builds pulls
from `ghcr.io/linuxserver/`. These rewrites exist only for the playground. When the v2 layout moves to the real
`linuxserver` org, swap every one back to the `ghcr.io/linuxserver/` name, or drop the commit. Upstream's
Dockerfiles never had these changes.

Each rewrite changes only the namespace in one kind of reference (a `FROM` or `COPY --from` image, a download
URL) in the Dockerfiles. Tags and file names are unchanged, and so is the rest of the Dockerfile. Every one is a
single commit with a fixed subject, so the commits can be found and reverted mechanically.

## Base images

Commit subject: `Build on the playground base images`. Rewrites
`ghcr.io/linuxserver/baseimage-<base>:<tag>` to `ghcr.io/linuxserver-playground/baseimage-<base>:<tag>`.

- **Trial:** python, kimai and planka.
- **First batch:** 118 branches from [the case study](base-image-case-study.md).
- **Follow-up:** 134 branches, the rest of the fleet. Among them, two base images build on other playground
  base images: baseimage-selkies (on alpine and debian) and baseimage-alpine-nginx (on alpine).
- **With the selkies-layers swap (below):** baseimage-selkies' other six live branches, `alpine324`, `arch`,
  `fedora44`, `kali`, `ubunturesolute` and `dev`, which the follow-up had missed.

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

## Mod scripts

Commit subject: `Fetch the mod scripts from the playground`. Rewrites the base images' `ADD` URLs
`https://raw.githubusercontent.com/linuxserver/docker-mods/mod-scripts/<script>` to
`linuxserver-playground/docker-mods/mod-scripts/<script>` for `docker-mods.v3`, `package-install.v1`, `lsiown.v1`
and `with-contenv.v1`, in every `Dockerfile*` (`Dockerfile.riscv64` too, where there is one; it is never built).
14 branches of 5 repos:

| Repo | Branches |
| --- | --- |
| docker-baseimage-alpine | `3.21`, `3.22`, `3.23`, `3.24`, `edge` |
| docker-baseimage-arch | `master` |
| docker-baseimage-debian | `bookworm`, `kali`, `master` |
| docker-baseimage-fedora | `43`, `44` |
| docker-baseimage-ubuntu | `jammy`, `noble`, `resolute` |

The playground's `docker-mods` `mod-scripts` branch is upstream's, pushed with its history and unchanged (no
workflows; nothing builds it). The scripts themselves still name `linuxserver`, and stay as upstream has them:

- `docker-mods.v3` reads the banned-publisher list from `linuxserver/docker-mods` `master` `blacklist.txt`, maps
  `linuxserver/*`, `docker.io/linuxserver/*` and `ghcr.io/linuxserver/*` mods to `lscr.io`, and sends a
  `linuxserver.io` user agent. A playground mod must be named in full, `ghcr.io/linuxserver-playground/mods:<tag>`:
  `linuxserver-playground/mods:<tag>` alone resolves to Docker Hub.
- `package-install.v1` installs Python packages with `-f https://wheel-index.linuxserver.io/...`, as most images
  still do (see wheelie above).

Every other image picks the playground scripts up from its base on its next rebuild. modmanager, which runs the
base's `/docker-mods` to fill `/modcache`, was rebuilt with the bases.

## selkies-layers

`linuxserver-playground/selkies-layers` carries two rewrite commits of its own:
- `Build on the playground base images`: the 23 `Dockerfile.<distro>.<layer>` `FROM` lines, tags unchanged
  (`baseimage-alpine:3.24`, `-arch:latest`, `-debian:trixie`, `-debian:kali`, `-fedora:44`, `-ubuntu:resolute`).
- `Publish the layers to the playground namespace`: `LAYERS_IMAGE` in `.github/workflows/build.yml`, the
  default `IMAGE` in `scripts/matrix.py`, and `README.md`.

The six `Dockerfile.*.wtype` files still clone `https://github.com/linuxserver/waylandtyper.git` (a source
checkout; the playground has no copy).

proot-apps needs no entry: every name in it follows `GITHUB_REPOSITORY`, as upstream designed it for forks.

### Images that copy the layers

Commit subject: `Use the playground selkies layers`. Rewrites `COPY --from=ghcr.io/linuxserver/selkies-layers:<tag>`
to `ghcr.io/linuxserver-playground/selkies-layers:<tag>` in `Dockerfile` and `Dockerfile.aarch64`. 15 branches of
5 repos:

| Repo | Branches | Layers |
| --- | --- | --- |
| docker-baseimage-selkies | `master`, `alpine324`, `arch`, `fedora44`, `kali`, `ubunturesolute`, `dev` | xvfb, wtype, labwc |
| docker-kali-linux | `master` | kwin |
| docker-lm-studio | `master` | kwin (amd64 only) |
| docker-pelorus | `master` | kwin (amd64 only) |
| docker-webtop | `alpine-kde`, `arch-kde`, `fedora-kde`, `ubuntu-kde`, `dev` | kwin |

Every other selkies desktop image gets the playground layers through baseimage-selkies on its next rebuild.

## Version sources

Commit subject: `Follow the playground's arch base image releases for the upstream version`. Not a Dockerfile:
`image.yml` `upstream.version` reads `linuxserver-playground/docker-baseimage-selkies`'s `arch-*` releases, the
base these branches build on. Upstream's commands read `linuxserver/docker-baseimage-selkies` (ardour,
lm-studio) and `linuxserver/docker-baseimage-kasmvnc` (webtop, a base those branches no longer use). Swap the
`repo:` back to `linuxserver/docker-baseimage-selkies` on all six.

| Repo | Branches |
| --- | --- |
| docker-ardour | `master` |
| docker-lm-studio | `master` |
| docker-webtop | `arch-i3`, `arch-kde`, `arch-mate`, `arch-xfce` |

## Still pointing at linuxserver

- tvheadend's `ghcr.io/linuxserver/picons-builder` stage: the playground has no picons-builder repo.
- The images in the base-image exceptions above.
- The `linuxserver` names inside the mod scripts, and `wheel-index.linuxserver.io` in most images (above).

## Finding and swapping them back

To list every remaining reference on a branch, run this in a clone:

```bash
git grep -n 'linuxserver-playground' origin/<branch> -- 'Dockerfile*'
```

To swap a branch back, either revert its commits or run the reverse rewrites:

```bash
sed -i -E 's#^(\s*FROM\s+)ghcr.io/linuxserver-playground/#\1ghcr.io/linuxserver/#' Dockerfile Dockerfile.aarch64
sed -i 's#ghcr.io/linuxserver-playground/selkies-layers:#ghcr.io/linuxserver/selkies-layers:#' Dockerfile Dockerfile.aarch64
sed -i 's#/linuxserver-playground/docker-mods/mod-scripts/#/linuxserver/docker-mods/mod-scripts/#' Dockerfile*
```

Then run `builder check` as for any change.
