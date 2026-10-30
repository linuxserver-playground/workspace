# Upstream donation links: survey of the image fleet

Surveyed 2026-10-30 over every `docker-*` repo with an `image.yml` (the checked-out branch; donation links do not vary by branch). The goal is to point users at the "support us" page of every project the playground packages: on the image page first, then in the repo the old way. `docs/donation-links.json` is the machine-readable result, keyed by image name, each value the list to put in `upstream.sponsor`.

## Where the fleet stands

| Status | Images | Meaning |
| --- | ---: | --- |
| found | 111 | an official donation path exists; 74 are new, 37 were already in `image.yml` (5 of those corrected) |
| none_found | 42 | open source, but the project advertises no way to give money (some refuse it) |
| commercial | 35 | a company's product with no donation path |
| own | 16 | LinuxServer.io's own images (base images, tools, webtop, heimdall, davos, pelorus) |
| skipped | 9 | a path exists but is not an unambiguous donation page (subscription, purchase, a maintainer's personal page); left out on purpose |

How the links were found, in order of authority: the `sponsor` list already in `image.yml` (37 images, from the Jenkins-era `sponsor_links`), the upstream repository's `.github/FUNDING.yml` and README on GitHub (38 images), then web research of the project's own site for the remaining 138 (eight batches, each link fetched once). Every proposed URL was requested once more with curl at the end: none is a 404; the 403s are Liberapay, PayPal and Cloudflare refusing a script, and those pages were read by the research pass.

## The holes in the pipeline

`image.yml` already has the field: `upstream.sponsor`, a list of `{name, url}` (schema `$defs.upstream.sponsor`). `builder migrate` carried `sponsor_links` into it. Nothing downstream uses it yet:

- **The container log.** The schema says the list is "written to /donate.txt in the image", and the base images' `init-adduser` still prints `/donate.txt` under "To support the app dev(s) visit:". But no step writes it: the 38 repos that print anything carry a Jenkins-era `root/donate.txt` by hand (mylar3 has the file but no `sponsor` list). Jenkins rendered it from `ansible/roles/repository/templates/donate.txt.j2` as a templated file.
- **The GitHub sidebar.** Jenkins rendered `.github/FUNDING.yml` (`github: linuxserver`, `open_collective: linuxserver`, `custom: [<upstream urls>]`), which is what put the "Sponsor this project" buttons on the side of every repo. The v2 conversion deleted the old `.github/` and `builder render` writes no FUNDING.yml, so no playground repo has one.
- **The hub** passes the manifest through as it is (`data/images/<name>/manifest.<branch>.json` carries `sponsor`), so the API side needs nothing.
- **The site** never reads it: nothing in `src/lib/hub.ts` or the image page mentions `sponsor`. This is the place the user asked for first.

So the work after this survey is: (1) builder renders `.github/FUNDING.yml` and `root/donate.txt` from `upstream.sponsor` as generated files (and `builder check` owns them), (2) the site shows the links prominently on the image page, (3) the lists below go into every live branch's `image.yml`, one commit per branch together with the release-notes fills from `docs/upstream-notes-fills.json`, so each branch builds once. Every push to a live branch is a full release build; that is the point of the playground, so the pushes are not paced.

## Left out on purpose

Only unambiguous donation pages go in. These have something, but not that:

- **ardour**: subscription, not a donation page
- **cura**: a company's GitHub Sponsors page
- **dolphin**: collective not linked from the project's site
- **fail2ban**: maintainer's personal links
- **homeassistant**: FUNDING.yml points at the Open Home Foundation home page, not a donate page
- **planka**: maintainer's personal page beside a paid product
- **ppsspp**: a purchase, not a donation
- **webgrabplus**: partly a paid tier
- **zotero**: storage plans, not a donation page
- **thelounge** and **piwigo** are listed as none_found on purpose: The Lounge asks people not to donate any more, and Piwigo only offers a contact form.
- **nomacs**, **duplicati**, **vscodium**: left out; their only channels are a dormant collective, an inactive collective beside a paid product, or a maintainer's personal links the project does not advertise.

## Every image

| Image | Status | Links | Notes |
| --- | --- | --- | --- |
| adguardhome-sync | found | [AdGuardHome Sync](https://github.com/sponsors/bakito) | already in image.yml |
| airsonic-advanced | none_found |  | README only links the EFF |
| altus | found | [Altus (GitHub Sponsors)](https://github.com/sponsors/amanharwara)<br>[Altus (Ko-fi)](https://ko-fi.com/amanharwara) |  |
| apprise-api | found | [Apprise](https://www.paypal.me/lead2gold) | already in image.yml |
| ardour | skipped |  | subscription, not a donation page |
| audacity | none_found |  | Open source (GPL) but owned and funded by Muse Group since 2021; the old https://www.audacityteam.org/donate/ returns 404, the homepage has no donate link and audacity/audacity has no FUNDING.yml. Only merch (merch.audacityteam.org). |
| audiosilo | found | [AudioSilo (GitHub Sponsors)](https://github.com/sponsors/KodeStar) |  |
| azahar | none_found |  | Homepage, README and FUNDING.yml carry no donation path; the only 'AZAHAR' donation page in search is an unrelated foundation. |
| babybuddy | found | [BabyBuddy](https://github.com/sponsors/cdubz) | already in image.yml |
| bambustudio | commercial |  | Commercial 3D-printer vendor's slicer; no donation path. |
| baseimage-alpine | own |  | LinuxServer.io project |
| baseimage-alpine-nginx | own |  | LinuxServer.io project |
| baseimage-arch | own |  | LinuxServer.io project |
| baseimage-debian | own |  | LinuxServer.io project |
| baseimage-fedora | own |  | LinuxServer.io project |
| baseimage-selkies | own |  | LinuxServer.io project |
| baseimage-ubuntu | own |  | LinuxServer.io project |
| bazarr | found | [Bazarr](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=XHHRWXT9YB7WE&source=url) | already in image.yml |
| beets | none_found |  | README has no donation link, no FUNDING.yml, no Sponsor button. |
| bitcoin-knots | none_found |  | Neither bitcoinknots.org nor the bitcoinknots/bitcoin README advertise a donation path; the maintainer's personal https://github.com/sponsors/luke-jr exists but does not mention Knots and is not linked from the project. |
| blade-of-agony | found | [Realm667 PayPal donate](https://www.paypal.com/donate?hosted_button_id=MCGC2LCJ5FHN6)<br>[Realm667 'Why donating?'](https://www.realm667.com/about/support-via-paypal) |  |
| blender | found | [Blender Development Fund](https://fund.blender.org/)<br>[Blender one-time donation](https://fund.blender.org/donate-once/) |  |
| boinc | none_found |  | boinc.berkeley.edu says BOINC is NSF-funded and only asks for computing time; no FUNDING.yml and no donate page found (SETI@home's donate page is a separate project). |
| bookstack | found | [Bookstack](https://www.bookstackapp.com/donate/) | already in image.yml |
| brave | none_found |  | Brave Software is a company; Brave Rewards/BAT tipping funds creators, not the project. No donation path found. |
| build-agent | own |  | LinuxServer.io project |
| calibre | found | [calibre](https://calibre-ebook.com/donate)<br>[calibre (GitHub Sponsors)](https://github.com/sponsors/kovidgoyal)<br>[calibre (Patreon)](https://www.patreon.com/kovidgoyal) |  |
| calibre-web | found | [Calibre-Web](https://paypal.me/calibreweb) | already in image.yml |
| calligra | found | [Donate to KDE e.V.](https://kde.org/donate/) |  |
| chrome | commercial |  | Google product, no donation path. |
| chromium | none_found |  | Google-run open-source project; the Linux Foundation's 'Supporters of Chromium-Based Browsers' fund is for corporate members, not a public donation page. |
| code-server | commercial |  | Open source but developed by Coder, a venture-backed company selling Coder Enterprise; no donation path. |
| cops | none_found |  | README has no donation link (only thanks JetBrains for free licences), no FUNDING.yml, no Sponsor button. |
| craft-apps | commercial |  | Subscription product with credit packs; no donation path. |
| cura | skipped |  | a company's GitHub Sponsors page |
| d2-builder | commercial |  | Terrastruct is a company; no FUNDING.yml (404) and no donation path. |
| darktable | none_found |  | No donate link on darktable.org or its About page and no FUNDING.yml; the footer only credits pixls.us for hosting. Forum threads point to individual developer Liberapay pages (Aurelien Pierre), which are not a project channel. |
| davos | own |  | LinuxServer.io project |
| ddclient | none_found |  | No FUNDING.yml on ddclient/ddclient and nothing in the README; a GitHub Sponsors link exists only on the rrthomas fork. |
| deluge | found | [Patreon (Calum Lind, lead developer)](https://www.patreon.com/deluge_cas) |  |
| digikam | found | [digiKam donate](https://www.digikam.org/donate/) |  |
| diskover | commercial |  | Diskover Data sells Pro/Enterprise editions; the community repo has no donation path. |
| dogwalk | found | [Blender Studio subscription](https://studio.blender.org/join/)<br>[Blender Development Fund](https://fund.blender.org/) |  |
| dokuwiki | found | [One-time donation via PayPal](http://donate.dokuwiki.org)<br>[Patreon](https://www.patreon.com/dokuwiki)<br>[GitHub Sponsors (Andreas Gohr, splitbrain)](https://github.com/sponsors/splitbrain) |  |
| dolphin | skipped |  | collective not linked from the project's site |
| dosbox-staging | found | [DOSBox Staging (GitHub Sponsors)](https://github.com/sponsors/dosbox-staging)<br>[DOSBox Staging (Open Collective)](https://opencollective.com/dosbox-staging) |  |
| doublecommander | none_found |  | No donation mention on the homepage or the doublecmd/doublecmd README, and no FUNDING.yml. |
| duckdns | found | [DuckDNS](https://www.patreon.com/user?u=3209735) | already in image.yml |
| duckstation | none_found |  | The project deliberately takes no donations: neither the site nor the repo offers any path, and third-party lists (RetroDECK wiki) record none. |
| duplicati | commercial |  | duplicati.com is now Duplicati Inc. with per-machine pricing; the old https://www.duplicati.com/donate/ page returns 404 and the Open Collective is labelled Inactive, though it still shows recent contributions. |
| eden | found | [Contribute page (Liberapay, PayPal, Bitcoin)](https://eden-emu.dev/contribute)<br>[Liberapay (crueter, Eden developer)](https://liberapay.com/crueter) |  |
| emby | commercial |  | Commercial product (Emby Premiere); no donation path. |
| fail2ban | skipped |  | maintainer's personal links |
| faster-whisper | commercial |  | SYSTRAN-maintained; no FUNDING.yml (404) and the README has no donation or sponsor link. |
| ferdium | found | [Ferdium](https://opencollective.com/ferdium) |  |
| ffmpeg | found | [FFmpeg donations](https://ffmpeg.org/donations.html)<br>[GitHub Sponsors](https://github.com/sponsors/FFmpeg) |  |
| filezilla | found | [Open Collective](https://opencollective.com/filezilla) |  |
| firefox | found | [Donate to the Mozilla Foundation](https://www.mozillafoundation.org/en/donate/) |  |
| flexget | found | [FlexGet](https://github.com/sponsors/gazpachoking/) | already in image.yml |
| flycast | found | [Flycast](https://www.paypal.com/paypalme/FlycastEmu)<br>[Flycast (Buy Me a Coffee)](https://www.buymeacoffee.com/hhwtpernwq) |  |
| foldingathome | found | [Folding@home](https://foldingathome.org/donate/) | corrected |
| freecad | found | [FreeCAD](https://wiki.freecad.org/Donate)<br>[FreeCAD (GitHub Sponsors)](https://github.com/sponsors/FreeCAD)<br>[FreeCAD (Open Collective)](https://opencollective.com/freecad) |  |
| freshrss | found | [FreshRSS (Liberapay)](https://liberapay.com/FreshRSS) |  |
| gimp | found | [GIMP donating page](https://www.gimp.org/donating/)<br>[GIMP on Liberapay](https://liberapay.com/GIMP/) |  |
| github-desktop | found | [GitHub Sponsors (shiftkey)](https://github.com/sponsors/shiftkey) |  |
| gitqlient | none_found |  | Open source (LGPL), single maintainer, no donation channel advertised. |
| grav | found | [Grav](https://opencollective.com/grav/donate) | already in image.yml |
| grocy | found | [grocy](https://grocy.info/#say-thanks) |  |
| gzdoom | none_found |  | No donation path on the repo; a ZDoom forum staff answer says the project has no means of donation. |
| habridge | none_found |  | No donate or sponsor link in the 1354-line README or any FUNDING.yml. |
| handbrake | none_found |  | Deliberately accepts no money: 'The HandBrake and HandBrake Documentation projects are not accepting monetary donations' and suggests VideoLAN (https://www.videolan.org/videolan/) or the Blender Foundation instead. |
| healthchecks | found | [GitHub Sponsors](https://github.com/sponsors/healthchecks) |  |
| hedgedoc | none_found |  | No donate/sponsor link on hedgedoc.org, docs.hedgedoc.org, the README or any FUNDING.yml; opencollective.com/hedgedoc is a 404. |
| heimdall | own |  | LinuxServer.io project |
| helium | found | [Sponsor Helium](https://helium.computer/sponsor) |  |
| hishtory-server | none_found |  | No donate or sponsor link on hishtory.dev or in the 349-line README. |
| homeassistant | skipped |  | FUNDING.yml points at the Open Home Foundation home page, not a donate page |
| htpcmanager | none_found |  | No donation link in README or repo; not archived but barely alive (last commit 2025-08-09, README asks for hands to finish Python 3 compatibility). |
| inkscape | found | [Donate to Inkscape](https://inkscape.org/support-us/donate/) |  |
| intellij-idea | commercial |  | Commercial IDE with a free Community Edition; no donation path. |
| jackett | none_found |  | README has no donation link, no .github/FUNDING.yml and no Sponsor button; it asks for development help, not money. |
| jellyfin | found | [Jellyfin](https://opencollective.com/jellyfin) | already in image.yml |
| joplin | found | [Joplin](https://joplinapp.org/donate/)<br>[Joplin (Patreon)](https://www.patreon.com/joplin)<br>[Joplin (GitHub Sponsors)](https://github.com/sponsors/laurent22) |  |
| kali-linux | own |  | LinuxServer.io project |
| kasm | commercial |  | Commercial product with a free tier; no donation path. |
| kavita | found | [Kavita](https://opencollective.com/kavita) | already in image.yml |
| kdenlive | found | [Kdenlive fund](https://kdenlive.org/fund/) |  |
| keepassxc | found | [KeePassXC donate](https://keepassxc.org/donate/)<br>[Open Collective](https://opencollective.com/keepassxc)<br>[Liberapay](https://liberapay.com/keepassxc) |  |
| kicad | found | [KiCad donate](https://www.kicad.org/donate/)<br>[KiCad on Linux Foundation crowdfunding](https://crowdfunding.linuxfoundation.org/projects/kicad) |  |
| kimai | found | [Kimai](https://www.kimai.org/donate/)<br>[Kimai (Open Collective)](https://opencollective.com/kimai)<br>[Kimai (GitHub Sponsors)](https://github.com/sponsors/kevinpapst) | corrected |
| kometa | found | [Kometa](https://github.com/sponsors/meisnate12) | already in image.yml |
| krita | found | [Krita donations](https://krita.org/en/donations/)<br>[Krita Development Fund](https://fund.krita.org/)<br>[Krita on Liberapay](https://liberapay.com/Krita) |  |
| lazylibrarian | found | [Buy Me a Coffee](https://buymeacoffee.com/philbormang) |  |
| ldap-auth | commercial |  | An NGINX Inc. (F5) reference implementation; the README points to NGINX Plus and NGINX Professional Services, no donation path. |
| libreoffice | found | [Support LibreOffice](https://www.libreoffice.org/donate/)<br>[LibreOffice via SPI (US tax-deductible)](https://www.spi-inc.org/donations/) |  |
| librespeed | found | [LibreSpeed (Liberapay)](https://liberapay.com/fdossena/donate)<br>[LibreSpeed (Paypal)](https://www.paypal.me/sineisochronic) | already in image.yml |
| librewolf | none_found |  | LibreWolf deliberately does not accept donations; contributions are welcome as merge requests. |
| lidarr | found | [Lidarr](https://opencollective.com/lidarr) | already in image.yml |
| limnoria | none_found |  | No donate or sponsor link in the README, FUNDING.yml or search results. |
| lm-studio | commercial |  | Proprietary; no donation path. |
| lollypop | found | [Patreon (Cédric Bellegarde, gnumdk)](https://www.patreon.com/gnumdk) |  |
| lsio-api | own |  | LinuxServer.io project |
| luanti | found | [Luanti](https://www.luanti.org/donate/)<br>[Luanti (Open Collective)](https://opencollective.com/luanti) |  |
| lychee | found | [Lychee (GitHub Sponsors)](https://github.com/sponsors/LycheeOrg)<br>[Lychee (Open Collective)](https://opencollective.com/LycheeOrg) |  |
| mame | none_found |  | MAME takes no direct donations; individual devs and ROM-dumping groups (Dumping Union) have their own Patreon/PayPal, none of which is MAME's official path. |
| manyfold | found | [Manyfold (Open Collective)](https://opencollective.com/manyfold) |  |
| mariadb | found | [MariaDB Foundation](https://mariadb.org/donate/) |  |
| mastodon | found | [Mastodon](https://joinmastodon.org/sponsors#donate) |  |
| mediaelch | none_found |  | No donate or sponsor link on the site, the docs or the README. |
| medusa | none_found |  | The wiki FAQ and sidebar link a 'Donations and support' page (wiki/Donations) that does not exist in the wiki repo; README has no link and no FUNDING.yml; pymedusa.com returns 403. |
| melonds | found | [melonDS](http://melonds.kuribo64.net/donate.php)<br>[melonDS (Patreon)](https://www.patreon.com/Arisotura)<br>[melonDS (PayPal)](https://paypal.me/Arisotura) |  |
| minisatip | found | [minisatip](https://paypal.me/minisatip)<br>[minisatip (GitHub Sponsors)](https://github.com/sponsors/catalinii) |  |
| modmanager | own |  | LinuxServer.io project |
| modrinth | commercial |  | Company-run platform (ads and creator monetisation); no donation path for the project itself. |
| msedge | commercial |  | Microsoft product, no donation path. |
| mstream | found | [mStream (GitHub Sponsors)](https://github.com/sponsors/IrosTheBeggar) |  |
| mullvad-browser | commercial |  | Funded by Mullvad VPN; no donation path. Co-developed with the Tor Project, which has its own donate page but is not this project. |
| mylar3 | none_found |  | README thanks people for 'financial donations' but gives no link; no FUNDING.yml, no Sponsor button, and the docs' contributing page lists only non-financial ways to help. |
| mysql-workbench | commercial |  | Oracle product; no donation path. |
| netbox | commercial |  | No FUNDING.yml or donation link; the README funnels to NetBox Labs' paid Cloud and Enterprise editions (netboxlabs.com). |
| nextcloud | commercial |  | FUNDING.yml custom link is nextcloud.com/include/, a contribute page; Nextcloud GmbH sells support |
| nginx | commercial |  | nginx.org offers no donation path; it links F5's enterprise distributions and commercial support (enterprise.html). |
| ngircd | none_found |  | No donation link on the project site, support page, README or GitHub org. A Liberapay profile https://liberapay.com/ngIRCd exists (member: alexbarton, the author; 0 patrons) but the project does not advertise it anywhere; not listed as a link for that reason. |
| nomacs | none_found |  | Weak: the collective is run by the nomacs maintainers (Stefan Fiel, Markus Diem) and links nomacs.org, but it is dormant ($0.56 raised since 2020) and neither nomacs.org nor the GitHub README advertises it; no FUNDING.yml. |
| nzbget | found | [NZBGet](https://nzbget.com/donate/) | already in image.yml |
| nzbhydra2 | found | [NZBHydra 2](https://github.com/sponsors/theotherp) | corrected |
| obsidian | commercial |  | Commercial, closed source. The only support-style purchase is the Catalyst license (plus Sync/Publish subscriptions and the commercial license); no donate link, reported as commercial with no link. |
| ombi | found | [Ombi - Patreon](https://patreon.com/tidusjar)<br>[Ombi - PayPal](https://paypal.me/PlexRequestsNet) | already in image.yml |
| onlyoffice | commercial |  | Open source desktop editors from a commercial vendor; no donation path. |
| openshot | found | [OpenShot](https://www.openshot.org/donate/) | already in image.yml |
| openssh-server | found | [OpenSSH donations](https://www.openssh.org/donations.html)<br>[OpenBSD Foundation donations](https://www.openbsdfoundation.org/donations.html) |  |
| opera | commercial |  | Opera Software product, no donation path. |
| orcaslicer | found | [OrcaSlicer](https://paypal.me/softfever3d)<br>[OrcaSlicer (GitHub Sponsors)](https://github.com/sponsors/SoftFever)<br>[OrcaSlicer (Ko-fi)](https://ko-fi.com/SoftFever) |  |
| oscam | none_found |  | streamboard.tv front page has no donation link; git.streamboard.tv is behind Anubis and board.streamboard.tv returns 403; web search finds no donation path. |
| pairdrop | found | [PairDrop](https://www.buymeacoffee.com/pairdrop) | already in image.yml |
| pcsx2 | found | [GitHub Sponsors](https://github.com/sponsors/PCSX2)<br>[Liberapay](https://liberapay.com/PCSX2) |  |
| pelorus | own |  | LinuxServer.io project |
| phpmyadmin | found | [phpMyAdmin](https://www.phpmyadmin.net/donate/) |  |
| pidgin | found | [Donate to Instant Messaging Freedom](https://imfreedom.org/donate/)<br>[Patreon (Gary Kramlich, Pidgin lead developer)](https://patreon.com/rw_grim) |  |
| piper | none_found |  | No FUNDING.yml on OHF-Voice/piper1-gpl or rhasspy/piper; the READMEs of piper1-gpl, rhasspy/piper and wyoming-piper advertise no donation path, only an Open Home Foundation badge and a call for maintainers. |
| piwigo | none_found |  | only a contact form for donations |
| planka | skipped |  | maintainer's personal page beside a paid product |
| plex | commercial |  | Commercial product (Plex Pass); no donation path. |
| ppsspp | skipped |  | a purchase, not a donation |
| projectsend | found | [ProjectSend (Patreon)](https://www.patreon.com/ignacionelson)<br>[ProjectSend (Open Collective)](https://opencollective.com/projectsend) |  |
| prowlarr | found | [Prowlarr](https://opencollective.com/prowlarr) | already in image.yml |
| pwndrop | found | [Pwndrop - Patreon](https://patreon.com/mrgretzky)<br>[Pwndrop - Ko-fi](https://ko-fi.com/mrgretzky)<br>[Pwndrop - Liberapay](https://liberapay.com/mrgretzky) | already in image.yml |
| pycharm | commercial |  | Commercial IDE with a free Community Edition; no donation path. |
| pydio-cells | commercial |  | Commercial product by Pydio (Enterprise edition); no donation path in the README or repo. |
| pyload-ng | found | [pyLoad](https://PayPal.Me/nitzo2001/0usd) | already in image.yml |
| python | found | [PSF donations](https://www.python.org/psf/donations/) |  |
| qbittorrent | found | [qBittorrent](https://www.qbittorrent.org/donate) |  |
| qdirstat | found | [QDirStat](https://www.paypal.me/shundhammer) | corrected |
| qemu-static | found | [QEMU donations](https://www.qemu.org/donations/)<br>[Donate via PayPal (Software Freedom Conservancy)](https://paypal.com/donate/?hosted_button_id=YN74TZRMBBM6U) |  |
| radarr | found | [Radarr](https://opencollective.com/radarr) | already in image.yml |
| raneto | none_found |  | No donate/sponsor link on raneto.com or in the README; docs.raneto.com could not be fetched (expired TLS certificate). |
| rawtherapee | found | [RawTherapee](https://www.paypal.com/paypalme/rawtherapee) | already in image.yml |
| remmina | found | [Remmina donations](https://remmina.org/donations/)<br>[Liberapay](https://liberapay.com/Remmina/donate)<br>[Open Collective](https://opencollective.com/remmina) |  |
| resilio-sync | commercial |  | Commercial product (Sync Home Pro licences); no donation path. |
| retroarch | found | [Donate page](https://retroarch.com/donate.html)<br>[Patreon](https://www.patreon.com/libretro)<br>[GitHub Sponsors](https://github.com/sponsors/libretro) |  |
| rpcs3 | found | [Patreon (Nekotekina)](https://www.patreon.com/Nekotekina) |  |
| rsnapshot | none_found |  | No FUNDING.yml, nothing on rsnapshot.org or the README; the only funding links found belong to linuxserver's docker-rsnapshot, not upstream. |
| rustdesk | found | [RustDesk (GitHub Sponsors)](https://github.com/sponsors/rustdesk)<br>[RustDesk (Ko-fi)](https://ko-fi.com/rustdesk) |  |
| sabnzbd | found | [SABnzbd](https://sabnzbd.org/donate) | already in image.yml |
| scummvm | found | [ScummVM](https://www.scummvm.org/donate-with-paypal) |  |
| sealskin | none_found |  | No FUNDING.yml on sealskin, selkies or the selkies-project .github repo; neither README mentions sponsorship. A personal GitHub Sponsors page for founder Dan Isla (github.com/sponsors/danisla) exists but the project does not advertise it. |
| shadps4 | found | [shadPS4 (Ko-fi)](https://ko-fi.com/shadps4) |  |
| shotcut | found | [Shotcut PayPal donate](https://www.paypal.com/donate?hosted_button_id=XD364WFCHD46N) |  |
| sickgear | none_found |  | README has no donation link, no FUNDING.yml, no Sponsor button; web search finds nothing. |
| signal | found | [Donate to Signal](https://signal.org/donate/) |  |
| smokeping | none_found |  | The project's 'become a Sponsor' link redirects to www.oetiker.ch/monitoring/sponsoring.var which returns 404; no other donation path is advertised, only sponsor logos and personal wish lists. |
| socket-proxy | none_found |  | No FUNDING.yml and no donation mention in the README; Tecnativa is a company. |
| sonarr | found | [Sonarr](https://sonarr.tv/donate) | already in image.yml |
| speedtest-tracker | found | [speedtest-tracker](https://github.com/sponsors/alexjustesen) | already in image.yml |
| spotube | found | [Spotube](https://opencollective.com/spotube) | already in image.yml |
| sqlitebrowser | found | [DB Browser for SQLite](https://www.patreon.com/db4s) | already in image.yml |
| steam | commercial |  | Commercial storefront; no donation path. |
| swag | found | [Certbot](https://supporters.eff.org/donate/support-work-on-certbot) | already in image.yml |
| synclounge | found | [SyncLounge](http://docs.synclounge.tv/contributing/donating/) | already in image.yml |
| syncthing | found | [Syncthing](https://syncthing.net/donations/)<br>[Syncthing (GitHub Sponsors)](https://github.com/sponsors/syncthing) |  |
| syslog-ng | commercial |  | No FUNDING.yml; README's Sponsors section lists companies (Balabit/One Identity, Axoflow) and asks only for a GitHub star; syslog-ng.com is the One Identity vendor site. |
| tautulli | found | [Tautulli](https://tautulli.com/#donate) | already in image.yml |
| telegram | commercial |  | Commercial messenger, no donation path. |
| thelounge | none_found |  | has an Open Collective but asks people not to donate any more |
| thunderbird | found | [Donate to Thunderbird](https://www.thunderbird.net/en-US/donate/)<br>[Thunderbird giving FAQ](https://give.thunderbird.net/) |  |
| transmission | found | [Donate (PayPal, one-time or monthly)](https://transmissionbt.com/donate/) |  |
| tvheadend | found | [Tvheadend (Open Collective)](https://opencollective.com/tvheadend) |  |
| ubooquity | found | [Donate (PayPal)](https://vaemendis.net/ubooquity/static8/donate) |  |
| ungoogled-chromium | none_found |  | The main project has no donation path; only individual platform packagers (macOS, Portapps) take personal sponsorships. |
| unifi-network-application | commercial |  | Proprietary hardware vendor software; no donation path. |
| unrar | commercial |  | Source-available freeware from RARLAB, the WinRAR vendor; one search found no donation mechanism. |
| vivaldi | found | [Donate to Vivaldi](https://vivaldi.com/donate/)<br>[Contribute to Vivaldi](https://vivaldi.net/contribute/) |  |
| vlc | found | [Donate to VideoLAN](https://www.videolan.org/contribute.html#money) |  |
| vscode | commercial |  | Microsoft product; MIT-licensed Code-OSS base, proprietary binaries. No donate page. |
| vscodium | none_found |  | No project donation page: vscodium.com has no donate section (checked the HTML), no .github/FUNDING.yml, only a root FUNDING.json with a Drips Ethereum address; recurring-donation issue #1870 closed not planned. Ko-fi returned 403 to curl (bot block), so unverified. |
| vscodium-web | none_found |  | Same result as vscodium. |
| webcord | found | [GitHub Sponsors (SpacingBat3)](https://github.com/sponsors/SpacingBat3) |  |
| webgrabplus | skipped |  | partly a paid tier |
| webstation | own |  | LinuxServer.io project |
| webtop | own |  | LinuxServer.io project |
| weixin | commercial |  | Tencent product, no donation path. |
| wikijs | found | [Wiki.js (GitHub Sponsors)](https://github.com/sponsors/NGPixel)<br>[Wiki.js (Patreon)](https://www.patreon.com/requarks)<br>[Wiki.js (Open Collective)](https://opencollective.com/wikijs) |  |
| winegui | found | [WineGUI](https://melroy.org/donate.html)<br>[WineGUI (GitHub Sponsors)](https://github.com/sponsors/melroy89)<br>[WineGUI (Patreon)](https://www.patreon.com/Melroy) |  |
| wireguard | found | [WireGuard](https://www.wireguard.com/donations/) | already in image.yml |
| wireshark | found | [Wireshark Foundation donate](https://wiresharkfoundation.org/donate/) |  |
| wps-office | commercial |  | Proprietary; no donation path. |
| xbackbone | found | [XBackBone (GitHub Sponsors)](https://github.com/sponsors/SergiX44) |  |
| xemu | found | [xemu (Patreon)](https://www.patreon.com/mborgerson) |  |
| yaak | found | [Yaak](https://github.com/sponsors/gschier) | corrected |
| yq | found | [yq (GitHub Sponsors)](https://github.com/sponsors/kislyuk) |  |
| zen | found | [Donate to Zen](https://zen-browser.app/donate)<br>[Patreon](https://www.patreon.com/zen_browser)<br>[Ko-fi](https://ko-fi.com/zen_browser) |  |
| znc | found | [PayPal donation](https://www.paypal.com/donate?hosted_button_id=X64ZH85FWE8SJ) |  |
| zotero | skipped |  | storage plans, not a donation page |
