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
