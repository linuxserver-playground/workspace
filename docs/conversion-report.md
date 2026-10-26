# Conversion report: images to the v2 layout

Each live branch carries one commit, `Convert to the v2 layout: image.yml replaces readme-vars and jenkins-vars, generated files rendered by builder`,
produced with `builder migrate` → review → `builder render` → `builder check` (`ok` on every branch; the only warnings are the
expected `Dockerfile`/`Dockerfile.aarch64` non-FROM differences). Legacy `Jenkinsfile`, `jenkins-vars.yml`, `readme-vars.yml`,
`README.md` and `.github/` were removed, `.jenkins-external` dropped from `.gitignore`. sonarr and swag were converted
earlier. This first batch was pushed after review and builds like any other live branch.

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

All 19 first builds passed (9 of them dispatched by hand, see AGENTS.md).

Found while converting:

- **`builder migrate` still copies Groovy-escaped commands verbatim** (doubled `\\` in lidarr's notes and
  nextcloud previous's version command), the same as qbittorrent and jellyfin in the first batch. Fixed since:
  migrate now undoes the Groovy escapes in version and notes commands.
- **migrate leaves `api_locations` empty** even for the servarr apps; they were filled by hand from the legacy
  proxy confs, as for radarr.
- **The hub's subfolder sample has no prefix rewrite.** Apps without an in-app base URL (syncthing, duplicati,
  nextcloud) relied on `rewrite /<name>(.*) $1 break;` in the legacy confs, so they are marked subdomain only
  here. heimdall is already marked `subfolder.supported: true` with "SWAG rewrites", but the generated
  sample does not rewrite, so it likely does not work.

## Third batch (2026-10-25)

Twenty more images, 28 live branches, converted and pushed the same way after the second batch built green.
Live branches that are deprecated upstream were not converted: jackett `development`, wireguard `legacy`,
firefox `kasm`, mylar3 `unstable`. changedetection.io was swapped for pairdrop because its name has a dot
(see below). Every version, notes and `require_assets` source was resolved live before pushing.

Subfolder support is set only where the hub's generated sample works as is. Apps whose legacy conf needs a
`rewrite` (freshrss, deluge, phpmyadmin, thelounge), a header in the main location (calibre-web's
`X-Script-Name`) or a location outside the prefix (emby's `/embywebsocket`) are subdomain only for now.

| Repo | Branches converted | Version source | Notes source | Proxy | Notes / open questions |
| --- | --- | --- | --- | --- | --- |
| docker-freshrss | master | `github_release` FreshRSS/FreshRSS | `github_release` | 80, subdomain only | Legacy subfolder needs a rewrite. |
| docker-emby | master, beta | master `github_release` MediaBrowser/Emby.Releases; beta `json` (first prerelease) | `github_release` | 8096, subdomain only | Migrate crashed on this repo (fixed in builder, below). The legacy `external_artifact_check` became `require_assets` for the amd64 and arm64 debs. master changelog 2020-11-03 "missing samba folder" → 2020-12-03 (commit date). |
| docker-calibre-web | master, nightly | `github_release`; nightly `github_commit` | same as version | 8083, subdomain only, `/opds`, `/kobo` | `build_armhf` dropped. |
| docker-grocy | master | `github_release` grocy/grocy | `github_release` | 80, subdomain only, `/api` | Changelog 2024-05-02 "Rebase to Alpine 3.21" → 2025-05-02. |
| docker-jackett | master | `github_release` Jackett/Jackett | `github_release` | 9117, subfolder (Base path override `/jackett`), `/api`, `/dl` | `development` is deprecated upstream; not converted. |
| docker-nzbget | master, testing | `github_release`; testing `json` (sha of the `testing` tag) | master `github_release`; none on testing | 6789, subfolder (any prefix), `/jsonrpc`, `/jsonprpc`, `/xmlrpc` | The legacy confs also match `/<user>:<pass>/jsonrpc`; `api_locations` cannot express that form. |
| docker-ombi | master, development | `github_release` (development `prerelease`) | `github_release` | 3579, subfolder (Base URL `/ombi`), `/api`, `/swagger` | master notes are empty because upstream's release body is empty. |
| docker-piwigo | master | `github_release` Piwigo/Piwigo | `github_release` | 80, subdomain only | |
| docker-wikijs | master | `github_release` Requarks/wiki-v2 | `github_release` | 3000, subdomain only, `/graphql` | Changelog 2022-08-25 "Rebase to Alpine 3.18" → 2023-08-25. |
| docker-librespeed | master | `github_release` librespeed/speedtest | `github_release` | 80, subdomain only | |
| docker-healthchecks | master | `github_release` healthchecks/healthchecks | `github_release` | 8000, subdomain only | |
| docker-smokeping | master | `alpine_apk` | none | 80, subfolder (serves `/smokeping`) | |
| docker-deluge | master, libtorrentv1 | `pip` deluge | none | 8112, subdomain only | Changelog 2019-05-09 "Add python3 requests" → 2020-05-09 on both. |
| docker-phpmyadmin | main | `command` (phpmyadmin.net `version.txt` is plain text; no typed source reads it) | none | 80, subdomain only | |
| docker-thelounge | master, next, nightly | `github_release` (next `prerelease`); nightly `github_commit` | same as version | 9000, subdomain only | next/nightly categories copied from master. |
| docker-pairdrop | main | `json` GitHub tags `.[0].name` (typed from the legacy curl) | none | 3000, subdomain only | |
| docker-duckdns | master | `os` | none | none | No web UI; tests run with dummy `SUBDOMAINS`/`TOKEN`. |
| docker-wireguard | master | `alpine_apk` | none | none | `builder check` failed on `init-wireguard-module/run`, which lacked `# shellcheck shell=bash`; the header was added in the conversion commit (no runtime change, no changelog entry). Tests are disabled, as in the legacy repo. `legacy` is deprecated; not converted. |
| docker-firefox | master | `deb_packages` xtradeb PPA `firefox` + transform stripping `[+~,]` (typed from the legacy curl; same result) | none | 3001 https, subdomain only | selkies base. `kasm` is deprecated; not converted. |
| docker-mylar3 | master, nightly | `github_release`; nightly `github_commit` | same as version | 8090, subdomain only | nightly category copied from master. `unstable` is deprecated; not converted. |

Found while converting:

- **Migrate crashed on emby** (`UndefinedError: 'secrets' is undefined`): it re-renders strings until they stop
  changing, so the escaped `${{ '{{' }} secrets.CR_PAT {{ '}}' }}` became `${{ secrets.CR_PAT }}` and then failed
  on the next pass. Fixed in builder (escaped expressions stay literal), with emby added as a live fixture.
  migrate now also points `external_artifact_check` at `require_assets`.
- **Categories copied to non-master branches were incomplete** in the second batch (only master's first
  category); lidarr develop/nightly and nextcloud develop/previous got a follow-up commit with master's full list.
- **Image names cannot contain a dot.** `changedetection.io` fails the schema's `name` pattern. Allowing it is a
  contract change (k8s object names, store ids, container names and site URLs all derive from `name`), so
  it needs a maintainer decision.

## Remaining fleet (2026-10-25 and 26)

Every other `linuxserver/docker-*` repo that is not deprecated, 176 images, in six batches (A to F), with
the playground now holding 216 `docker-*` repos. These were converted by a driver script rather than by hand.
After each `builder migrate`, the driver:

- copies the default branch's categories to the other branches;
- fills the proxy block from `linuxserver/reverse-proxy-confs`. The main location gives the port and scheme.
  Same-port locations without auth become `api_locations`, and other-port ones become `extra_locations`.
  Subfolder is off wherever the legacy conf needs a rewrite, `sub_filter`, `X-Script-Name` or a location
  outside the prefix;
- fixes changelog dates (the commit date, else a stable sort);
- maps device placeholders to `/dev/ttyUSB0`;
- adds missing `# shellcheck shell=bash` headers;
- rewrites `#!/command/with-contenv` shebangs to `/usr/bin/with-contenv`.

It then renders, runs `builder check` and resolves the version live before the push. Live branches
deprecated upstream were not converted. Neither were deprecated repos (baseimage-el, budge, doplarr,
openvscode-server), helpers (documentation, templates), or ci and jenkins-builder, which the playground
replaces.

| Batch | Repos pushed | Branches | Failing after reruns and fixes |
| --- | --- | --- | --- |
| A | 30 | 59 | baseimage-kasmvnc, all 9 branches |
| B | 29 | 32 | davos, github-desktop, ffmpeg `bin` |
| C | 30 | 32 | intellij-idea |
| D | 30 | 33 | manyfold |
| E | 30 | 33 | none |
| F | 25 | 34 | xvfb `ubunturesolute`, `kali`, `fedora43`; tvheadend `j0nny`; webstation cancelled (below) |

**Failures where the source was already broken**: the same commit fails upstream on Jenkins, or upstream has not
built it in months.

| Image | Reason |
| --- | --- |
| baseimage-kasmvnc (9 branches) | apk "unable to select packages"; upstream unbuilt since July 2025, published images April to July 2025. Never published to the playground |
| davos | `docker.io/library/openjdk:8-alpine` no longer exists; Jenkins failing since January 2026 |
| github-desktop | `sed` cannot find `codium.desktop` after codium 1.140; Jenkins failing |
| intellij-idea | the version command prints nothing; Jenkins failing |
| manyfold | asset precompile cannot reach redis during the build; Jenkins failing |
| ffmpeg `bin` | amd64 tests fail and the arm64 x265 compile fails; branch head from 2023, never built by Jenkins |
| xvfb `ubunturesolute`, `kali`, `fedora43` | `apt-get build-dep` fails; Jenkins failing since August 2026. xvfb is abandoned, so these stay red |
| tvheadend `j0nny` | s6 v2 `cont-init.d` scripts without the executable bit; branch never built by Jenkins |

**Failures that were ours**, all fixed and rebuilt green:

| Image | Cause | Fix |
| --- | --- | --- |
| python `alpine324`, `ha`; qemu-static | `jq '.test.enabled // true'` reads `false` as missing, so disabled tests still failed the build | workflows: honour `test.enabled: false` |
| socket-proxy, python, qemu-static | the harness failed every image without `/etc/s6-overlay/s6-rc.d` at the Init graph step | ci: skip the init graph for images without s6 |
| kimai | Actions dropped the prepare job's `manifest_json` output ("may contain secret"): some masked value matched text in the manifest | workflows: the manifest travels as an artifact, not a job output |
| webgrabplus | curl exits 23 (write error) when `grep -m1` closes the pipe; only SIGPIPE's 141 was accepted | workflows (and control's vendored resolver): accept 23 too |

**Not built:** webstation was cancelled by a maintainer. It compiles three emulators and is too heavy to build alongside the rest; it is staged but has no release.

**Transient**, green on rerun: baseimage-selkies `dev`, helium (GHCR token EOF), homeassistant (uv download),
ffmpeg `bin`'s first attempt (502). planka failed twice on the Alpine mirror and built green once moved to the
playground base image (see `docs/base-image-case-study.md`).

**Tool fixes made along the way:**

- builder migrate undoes Groovy escapes in commands;
- `MULTIARCH: false` becomes an amd64-only platform list;
- text an earlier render pass produced is kept when it is not a template (the `{% raw %}` case);
- escaped GitHub expressions stay literal;
- workflows takes the base image from the last `FROM`, the runtime stage;
- ci reads the base image's layers from the registry when it is not local, so `from_base` is filled fleet-wide;
- the resolver accepts SIGPIPE (and now curl's 23) from command sources.

**Open:**

- **Names with `.` or `_`.** changedetection.io, doplarr_rs and your_spotify fail the schema's `name` pattern
  and are not staged. This needs a maintainer decision (see the third batch).
- **Unresolved versions.** intellij-idea prints nothing upstream too.
- **53 branches still use a `command` version source** that migrate did not recognise; typed sources would be
  better.
- **7 `external_artifact_check`s were dropped** because they read `${{ secrets.CR_PAT }}`. Those branches have
  no `require_assets` yet.
- **The hub's subfolder sample cannot rewrite,** so many apps are subdomain only (see the second batch).
