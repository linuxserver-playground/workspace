# workspace

The maintainers' workbench for broad, fast changes to the
[LinuxServer.io v2 playground](https://github.com/linuxserver-playground). Clone this repository, run the
bootstrap and start your coding agent at its root. Every other repository lands in `repos/`, so the agent
can follow a change from the builder contracts through the workflows, the hub and the website.

For the guided path, with role-aware playbooks for team members and outside contributors, use
[harness](https://github.com/linuxserver-playground/harness) instead. When an architecture change lands
here, update the harness to match (AGENTS.md, "Keeping the harness in step").

```bash
gh repo clone linuxserver-playground/workspace && cd workspace
./bootstrap.sh --setup        # clones everything into repos/, installs the dev environments
claude                        # or any agent that reads AGENTS.md
```

| File | What |
| --- | --- |
| `AGENTS.md` | The system map: what each repo does, how a change goes live, recipes for the common cross-repo changes, the rules. `CLAUDE.md` imports it. |
| `DECISIONS.md` | Settled design decisions. Read before proposing a different direction. |
| `bootstrap.sh` | Clones or fast-forwards every org repo (`--setup` for dev environments, `--reference` for the read-only `linuxserver/*` originals). |
| `.claude/` | Shared Claude Code settings and slash commands (`/fleet-status`, `/new-image`, `/release-workflows`, `/refresh-hub`). |
| `docs/` | Working notes worth keeping: the conversion report for every staged image, build failure triage, what running the fleet on free GitHub runners costs, the base image case study, `single-build-package-check.md` (how a live build releases and keeps `package_versions.txt` current in one run, and how the build page says why it built), the plan for the harness repo, `donation-links.md` with `donation-links.json` (every image's upstream donation page, the fleet survey behind `upstream.sponsor`), `upstream-notes-inventory.md` with `upstream-notes-fills.json` (which branches get upstream release notes and the `upstream.notes` blocks that fill the gaps), and `live-cutover.md`, the running list of what the move to the real `linuxserver` org must change. |

Open work is tracked in this repository's issues.
