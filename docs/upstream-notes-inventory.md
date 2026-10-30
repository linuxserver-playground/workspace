# Upstream release notes: fleet inventory (2026-10-30)

Every live release gets three sections in its GitHub Release body and in the hub's `build.json`
(CONVENTIONS §7): CI, LinuxServer changes, and **Upstream changes**, the text `upstream.notes` fetches
(`workflows/scripts/upstream_notes.py`). The site's build page renders it and links `upstream_url`. This
inventory checked every live branch of every `docker-*` repo (291 branches, 214 repos) for whether a notes
source is configured and whether the newest build's notes actually hold text, then probed each candidate
fix against the real upstream API with the workflow's own resolver and the version the newest build used.

## Totals

| | Branches |
| --- | --- |
| App branches with `upstream.notes` set and text arriving | 128 (2 more have not built yet) |
| App branches with `upstream.notes` set but the upstream release body is empty | 5 |
| App branches without `upstream.notes` | 122 |
| Base image branches (`kind: base`), no notes by design | 25 |
| Tool branches (`kind: tool`) | 9 (1 set: d2-builder) |

Of the 122 unconfigured app branches: 28 are `os`-versioned (webtop variants, chromium, gimp, steam and
the like), 6 are a `github_release` source that tracks the playground base image rather than the app
(ardour, lm-studio, the arch webtops), and the rest resolve their version from a package index, a JSON or
regex source, or pip. The gaps below are sorted by what it takes to fill them.

## 1. Fillable now, with the existing notes types (24 branches)

Each row was verified: the block below, fed the newest build's upstream version, returned the text shown.

| Image@branch | Version seen | `upstream.notes` | Result |
| --- | --- | --- | --- |
| apprise-api@main | v2.0.2 | `github_release` caronc/apprise-api | 1.0 kB |
| audacity@main | 4.0.1 | `github_release` audacity/audacity, tag `Audacity-${VERSION}` | 3.3 kB |
| beets@master | 2.14.1 | `github_release` beetbox/beets, tag `v${VERSION}` | 1.9 kB |
| brave@master | 1.98.63 | `github_release` brave/brave-browser, tag `v${VERSION}` | 1.3 kB |
| brave@borigin | 1.101.3 | same block | 0.8 kB (nightly notes) |
| duplicati@development | v2.3.1.1_beta_2026-08-26 | `github_release` duplicati/duplicati | 7.7 kB |
| eden@master | v0.2.1 | `gitea_release` base_url https://git.eden-emu.dev, repo eden-emu/eden | 6.6 kB |
| handbrake@master | 1.11.2 | `github_release` HandBrake/HandBrake | 1.7 kB |
| intellij-idea@master | 2026.2.3 | `github_release` JetBrains/intellij-community, tag `idea/${VERSION}` | link to YouTrack notes |
| luanti@main | 5.18.0 | `github_release` luanti-org/luanti | link to changelog |
| nzbget@testing | 82e07f0 | `github_commit` nzbgetcom/nzbget, branch develop | commit message |
| obsidian@main | v1.14.5 | `github_release` obsidianmd/obsidian-releases | link to changelog |
| pairdrop@main | v1.11.2 | `github_release` schlagmichdoch/PairDrop | 0.5 kB |
| pcsx2@master | 2.8.2 | `github_release` PCSX2/pcsx2, tag `v${VERSION}` | 0.3 kB |
| phpmyadmin@main | 5.2.3 | `rss` https://www.phpmyadmin.net/news/feed/, title `phpMyAdmin ${VERSION} is released` | full announcement (HTML) |
| piper@main | 2.5.2 | `github_release` OHF-Voice/wyoming-piper, tag `v${VERSION}` | 0.7 kB |
| qbittorrent@libtorrentv1 | 5.3.0_v1.2.20 | master's `command` block with `${VERSION%%_v1*}` | 9.9 kB |
| signal@master | 8.33.0 | `github_release` signalapp/Signal-Desktop, tag `v${VERSION}` | one line |
| synclounge@master | 5.2.35 | `github_release` synclounge/synclounge, tag `v${VERSION}` | 5.3 kB |
| telegram@master | 7.3.3 | `github_release` telegramdesktop/tdesktop, tag `v${VERSION}` | 0.7 kB |
| vscode@master | 1.144.0 | `github_release` microsoft/vscode | link to release notes |
| xemu@master | v0.8.134 (static) | `github_release` xemu-project/xemu | 2.7 kB |
| yaak@main | v2026.9.0 | `github_release` mountain-loop/yaak | 3.2 kB |
| yq@master | 4.4.5 | `github_release` kislyuk/yq, tag `v${VERSION}` | one line |

phpMyAdmin also has GitHub releases (`RELEASE_5_2_3`), but their body is only download links; the news
feed carries the changes. The `rss` matcher needs the exact title, so a joint release ("4.9.11 and 5.2.1
are released") would come back empty; that is upstream's choice.

## 2. Fillable once `upstream.notes` can transform the version (15 branches)

The notes `tag` template only substitutes `${VERSION}`; it cannot drop a packaging suffix. Every
`alpine_apk` version carries `-rN`, every `arch_package` version `-N`, and the deb sources carry
`+dfsg…`/`~ubuntu…`. The version source must keep those (they are part of the release tag, as upstream's
are), so the fix is a `transform` list on the notes block, the same shape as the version source's
(`#/$defs/transform`), applied before the tag lookup. Builder: schema, CONVENTIONS §7; workflows:
`upstream_notes.py` (`rv.apply_transforms`) and tests. Each row was verified with the transform applied.

| Image@branch | Version seen | Transform | `upstream.notes` | Result |
| --- | --- | --- | --- | --- |
| azahar@master | 1:2126.2-1 | `^\d+:` and `-\d+$` → `` | `github_release` azahar-emu/azahar | 1.7 kB |
| bitcoin-knots@master | 29.4.knots20260508.3-resolute1 | `(\.\d+)?-resolute\d+$` → `` | `github_release` bitcoinknots/bitcoin, tag `v${VERSION}` | 5.6 kB |
| boinc@master | 8.2.8+dfsg+… | `^(\d+\.\d+)\.(\d+).*$` → `client_release/\1/\1.\2` | `github_release` BOINC/boinc | 1.1 kB |
| darktable@master | 5.6.2-1 | `-\d+$` → `` | `github_release` darktable-org/darktable, tag `release-${VERSION}` | 7.4 kB |
| fail2ban@main | 1.1.0-r2 | `-r\d+$` → `` | `github_release` fail2ban/fail2ban | 0.4 kB |
| keepassxc@master | 2.7.12-r1 | `-r\d+$` → `` | `github_release` keepassxreboot/keepassxc | 1.0 kB |
| kicad@master | 10.0.3-r0 | `-r\d+$` → `` | `github_release` KiCad/kicad-source-mirror | 0.3 kB |
| nginx@master | 1.30.6-r0 | `-r\d+$` → `` | `github_release` nginx/nginx, tag `release-${VERSION}` | 1.0 kB |
| ngircd@master | 27-r1 | `-r\d+$` → `` | `github_release` ngircd/ngircd, tag `rel-${VERSION}` | 9.4 kB |
| openshot@main | 4.0.1+dfsg2+… | `\+.*$` → `` | `github_release` OpenShot/openshot-qt, tag `v${VERSION}` | 11.9 kB |
| ppsspp@master | 1.20.4-4 | `-\d+$` → `` | `github_release` hrydgard/ppsspp, tag `v${VERSION}` | 0.2 kB |
| rsnapshot@master | 1.4.5-r0 | `-r\d+$` → `` | `github_release` rsnapshot/rsnapshot | "See Changelog" |
| sqlitebrowser@master | 3.13.1-r1 | `-r\d+$` → `` | `github_release` sqlitebrowser/sqlitebrowser, tag `v${VERSION}` | 5.8 kB |
| syslog-ng@main | 4.11.0-r0 | `-r\d+$` → `` | `github_release` syslog-ng/syslog-ng, tag `syslog-ng-${VERSION}` | 7.7 kB |
| transmission@master | 4.1.4-r0 | `-r\d+$` → `` | `github_release` transmission/transmission | 4.6 kB |

Without the contract change, each of these could be a `command` block (as jellyfin, mariadb and
qbittorrent are today), but fifteen copies of a curl-and-jq one-liner is what the typed sources exist to
avoid.

## 3. Fillable once the `json` notes type keeps whole output (1 branch, and a latent bug)

`upstream_notes._json` runs the jq expression through `rv.run_jq`, which returns only the first non-empty
line and raises on none. No image uses `json` notes yet, so nobody has hit it, but it makes the type
useless for notes: a changelog is many lines. Fix: join the full `-r` output. While there, substitute
`${VERSION}` into the jq expression too, so the item can be selected by version.

| Image@branch | Source | Notes |
| --- | --- | --- |
| plex@master | https://plex.tv/api/downloads/5.json | `.computer.Linux` carries `items_added` and `items_fixed` as newline-separated text for the current version; jq can select by `.version == "${VERSION}"` and print both under two headings. |

## 4. Configured, but upstream's release body is empty (5 branches)

blade-of-agony (Realm667/WolfenDoom v3.1), flexget (v3.22.9), minisatip (v2.0.183), ombi@master
(v4.53.10) and ungoogled-chromium (156.0.8078.73-1). Checked directly: the GitHub release exists and its
body is zero bytes. Nothing to fix on our side; the page still links the release.

## 5. Nothing machine-readable upstream (the rest)

Checked and found no release body, no releases, or no feed that names the version:

- **GitHub releases exist but every body is empty:** mame (`mame0289`), retroarch (`v1.22.2`),
  dokuwiki (newest `release-2026-07-14c` is empty; older ones have a line or two).
- **Tags only, no releases:** deluge, dolphin (the 2609a tag has no release), limnoria, wireshark, znc,
  inkscape, vlc, ffmpeg, libreoffice, mysql-workbench, foldingathome, unrar, wireguard-tools, pyload
  (releases stop at 0.4.x; 0.5 dev builds have none), remmina (GitHub releases stop at 1.2.x).
- **No releases API at all:** smokeping, lollypop.
- **Codeberg releases lag the tags:** librewolf (releases end at 153.x, tags are at 159.0-1).
- **Blender's Gitea** refuses the releases API without a login.
- **Feeds without a usable title:** krita's feed titles the minor ("Krita 5.3.4 Released!") while the
  version is 5.3.4.1; kdenlive.org and digikam.org serve no feed at the usual paths.
- **Vendor pages only, no API:** chrome, firefox, thunderbird, msedge, opera, vivaldi, calligra, filezilla,
  pidgin, openssh-server, socket-proxy (haproxy), resilio-sync, ubooquity, webgrabplus, zotero, wps-office,
  oscam, unifi-network-application (the firmware API links a changelog that returns "not uploaded").
- **Version is not the app's:** ardour, lm-studio and the arch webtops track the baseimage-selkies
  release; python, qemu-static, ldap-auth, calibre@v4 (static); jellyfin@nightly, lidarr@nightly,
  prowlarr@nightly and radarr@nightly (the servarr `changes` endpoint carries `changes` for master but
  not for nightly).

For the vendor-page group a `link` notes type (URL template, no text) would at least let the build page
and the Release point at the right release notes page: Firefox, Thunderbird, Wireshark, Inkscape and
LibreOffice all have a stable per-version URL. The site already shows `upstream_url` as the source link
when it is http(s); the Release body would need "See <url>" in place of "No upstream notes." That is a
contract addition for the maintainers to weigh, not done here.

## Rolling it out

The contract change landed on 2026-10-30: builder `527940c` (schema and CONVENTIONS §7) and workflows
`fdb8383`, with `v1` moved to it. Image builds install builder from main at build time, so `builder check`
accepts `transform` on `upstream.notes` from then on. `docs/upstream-notes-fills.json` holds the exact block
for every branch in sections 1 to 3, keyed `image@branch`; the sponsor pass (`docs/donation-links.json`)
is applied in the same commit per branch so no branch builds twice.

A push to a live branch is a release build, so each filled `image.yml` costs one two-arch build; the notes
step only runs in the publish job, so nothing else about the build changes.
