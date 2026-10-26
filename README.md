# workspace

The way in for anyone, human or agent, working on the
[LinuxServer.io v2 playground](https://github.com/linuxserver-playground). Clone this repository, run the
bootstrap and start your coding agent at its root. Every other repository lands in `repos/`, so the agent
can follow a change from the builder contracts through the workflows, the hub and the website.

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
| `docs/` | Working notes worth keeping: the conversion report for every staged image, and the base image case study. |

Open work is tracked in this repository's issues.
