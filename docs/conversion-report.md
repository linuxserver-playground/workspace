# Conversion report: curated images to the v2 layout

Each live branch carries one commit, `Convert to the v2 layout: image.yml replaces readme-vars and jenkins-vars, generated files rendered by builder`,
produced with `builder migrate` → review → `builder render` → `builder check` (`ok` on every branch; the only warnings are the
expected `Dockerfile`/`Dockerfile.aarch64` non-FROM differences). Legacy `Jenkinsfile`, `jenkins-vars.yml`, `readme-vars.yml`,
`README.md` and `.github/` were removed, `.jenkins-external` dropped from `.gitignore`. Nothing was pushed; sonarr and swag untouched.

| Repo | Branches converted | Version source | Notes source | Proxy | Notes / open questions |
| --- | --- | --- | --- | --- | --- |
| docker-radarr | master, develop, nightly | `json` (servarr update API, `.[0].version`) | `github_release` Radarr/Radarr `v${VERSION}` (master, develop); none on nightly (legacy had none) | 7878, subdomain, subfolder supported (Settings → General → URL Base, `/radarr`), `/api` | Legacy dates `11.30.20`/`11.28.20`/`09.27.20` were MM.DD.YY; kept as 2020-11-30, 2020-11-28, 2020-09-27. Legacy commit-hash linkifying `sed` dropped in favour of the typed source. |
| docker-prowlarr | main, develop, nightly | `json` (servarr update API) | `github_release` Prowlarr/Prowlarr `v${VERSION}` (main, develop); none on nightly | 9696, subdomain, subfolder supported (URL Base `/prowlarr`), `/api` | develop/nightly categories copied from main (`Indexers`). |
| docker-qbittorrent | master, libtorrentv1 | master: `github_release` userdocs/qbittorrent-nox-static + regex transform; libtorrentv1: same with `prerelease: true`, `exclude: ^(?!.*v1\.2)` (typed by hand from the `jq ... contains("v1.2")` command) | master: `command` (legacy curl kept; the tag needs `${VERSION%%_v2*}`, which the typed `tag` template cannot express); none on libtorrentv1 | 8080, subdomain, subfolder not supported | Un-doubled the `\\` escapes in the notes command (they were Groovy-escaped). Changelog: `09.02.17` "Rebase to alpine 3.7" → 2017-12-09 (commit date); duplicate trailing "Initial Release." (2018-02-12) moved into date order rather than deleted. |
| docker-plex | master | `json` plex.tv downloads `.computer.Linux.version` | none (legacy had none) | 32400, subdomain only | Swapped the 2015-09-17 / 2015-09-19 changelog entries into order. |
| docker-code-server | master | `github_release` coder/code-server, strip `^v` | `github_release` coder/code-server `v${VERSION}` | 8443, subdomain only | Changelog `HASHED_PASSWORD` entry 2020-02-04 → 2021-02-04 (commit date). |
| docker-heimdall | master, development | master: `github_release` linuxserver/Heimdall; development: `github_commit` branch `2.x` | master: `github_release` (tag `${VERSION}`); development: `github_commit` | 80, subdomain, subfolder supported (no in-app base URL; SWAG rewrites) | Changelog "Generate random app key" 2018-01-16 → 2019-01-16 (commit date). |
| docker-webtop | master, ubuntu-kde, alpine-kde | `os` | none | 3001 https, subdomain only | master `release.tags` keeps all 23 legacy tags with a comment; unconverted ones carry `deprecated: false`, no branches created. ubuntu-kde/alpine-kde use the legacy `custom_readme` pointer; their placeholder summary/upstream URL were replaced by master's. Swapped 2021-09-21/2021-09-26 changelog entries. |
| docker-jellyfin | master, nightly | `deb_packages` repo.jellyfin.org resolute main / unstable | master: `command` (legacy curl; needs `${VERSION%%+ubu*}`); none on nightly | 8096, subdomain only | Un-doubled `\\` escapes in the notes command. |
| docker-bookstack | master | `codeberg_release` bookstack/bookstack | `codeberg_release` (tag `${VERSION}`) | 80, subdomain, subfolder supported (APP_URL incl. subfolder) — block added, legacy had `CI_WEB=false` | Changelog `2028-09-23` → 2018-09-23. |

Unsure about: the `exclude` negative-lookahead for qbittorrent libtorrentv1 relies on the resolver using Python `re` (it does today);
the two `command` notes sources (qbittorrent, jellyfin) could become typed if `notes.tag` ever learns a transform.

## Second batch (2026-10-25)

Ten more images, converted the same way (one conversion commit per live branch, `builder check` `ok` on all 19
branches, only the expected Dockerfile non-FROM warnings) and pushed: only the live branches (where
`ls_branch` names the branch), with history. Stale branches (`deny-dotfile-access*` on nextcloud,
`master-3.24`/`develop-3.24` on bazarr, a `copilot/` branch on openssh-server) were not pushed. Every version
and notes source was resolved live with `workflows/scripts/resolve_version.py` and `upstream_notes.py` before
pushing. Subfolder support comes from the legacy `linuxserver/reverse-proxy-confs` samples. Not built locally:
the conversion touches no Dockerfile or `root/`, and the pipeline builds and tests every branch.

| Repo | Branches converted | Version source | Notes source | Proxy | Notes / open questions |
| --- | --- | --- | --- | --- | --- |
| docker-lidarr | master, develop, nightly | `json` (servarr update API, `.[0].version`) | `github_release` Lidarr/Lidarr `v${VERSION}` (master, develop); none on nightly | 8686, subfolder supported (URL Base `/lidarr`), `/api` | As radarr: the Groovy-escaped commit-linkifying `sed` notes command replaced by the typed source. develop/nightly categories copied from master. |
| docker-bazarr | master, development | `github_release` morpheus65535/bazarr (development: `prerelease: true`) | `github_release` | 6767, subfolder supported (URL Base `/bazarr`), `/api` | master changelog `2021-15-15` (invalid date, migrate flagged it) → 2021-11-15 (commit date); development `2019-12-19` "Rebasing to alpine 3.12" → 2020-06-01. |
| docker-sabnzbd | master, unstable, nightly | `github_release` (unstable `prerelease: true`); nightly `github_commit` branch `develop` | same as version | 8080, subfolder supported (serves `/sabnzbd` by default), `/api`, note about `host_whitelist` | Changelog `2015-01-23` "Refresh image." → 2016-01-23 on all three. |
| docker-syncthing | master | `github_release` syncthing/syncthing | `github_release` | 8384, subdomain only, `/rest` | Legacy subfolder conf strips the prefix with `rewrite`; the hub generator cannot, so subfolder is off (see below). |
| docker-transmission | master | `alpine_apk` edge/community `transmission-daemon` | none (legacy had none) | 9091, subfolder supported (serves `/transmission`), `/rpc` | `DIST_TAG = edge` unmapped; it is already in `repo_url`. |
| docker-mariadb | master | `alpine_apk` v3.24/main `mariadb` | `command` (legacy curl; needs `${VERSION%%-r*}`) | none (not a web app) | Changelog `2025-02-14` "Rebase to Alpine 3.23" → 2026-02-14 (commit date). |
| docker-nextcloud | master, develop, previous | `command` on all three (legacy curl kept: `sort -rV` over all releases, which `github_release` cannot do since Nextcloud publishes old-major patches after newer majors) | `github_release` nextcloud-releases/server `v${VERSION}` | 443 https, subdomain only | Un-doubled the `\\"rc\\"` escapes in previous's command. develop/previous categories copied from master. |
| docker-tautulli | master, develop | `github_release`; develop `github_commit` branch `nightly` | same as version | 8181, subfolder supported (HTTP Root `/tautulli`), `/api`, `/newsletter`, `/image` | develop category copied from master. |
| docker-openssh-server | master | `alpine_apk` v3.24/main `openssh-server-pam` | none | none | Converted with no edits: the cleanest migrate output so far. |
| docker-duplicati | master, development | master `github_release`; development `json` over the GitHub releases API (first `beta` tag) | master `github_release`; none on development (legacy had none) | 8200, subdomain only | Subfolder off for the same reason as syncthing. |

Found while converting:

- **`builder migrate` still copies Groovy-escaped commands verbatim** (doubled `\\` in lidarr's notes and
  nextcloud previous's version command), the same as qbittorrent and jellyfin in the first batch. Every
  `command` source needs a manual un-doubling; migrate could do it, or at least flag it.
- **migrate leaves `api_locations` empty** even for the servarr apps; they were filled by hand from the legacy
  proxy confs, as for radarr.
- **The hub's subfolder sample has no prefix rewrite.** Apps without an in-app base URL (syncthing, duplicati,
  nextcloud) relied on `rewrite /<name>(.*) $1 break;` in the legacy confs, so they are marked subdomain only
  here. heimdall is already marked `subfolder.supported: true` with "SWAG rewrites", but the generated
  sample does not rewrite, so it likely does not work.
