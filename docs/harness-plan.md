# The harness: running the org with AI agents

A plan for `linuxserver-playground/harness`. Its main job is to show team members how to manage the whole org
with an AI agent. A team member clones it on their own machine (with Docker), starts a coding agent at its
root, and asks things like:

- "What PRs are open, and which matter most?"
- "Prioritise the open issues."
- "Explain this bug to me. What are the consequences?"
- "Review this PR and test it locally."
- "Add an image for X."
- "Add a field to image.yml and show it on the site."

The agent knows the whole system, pulls live data, tests in local Docker, and turns the answer into issues and
pull requests that someone reviews.

Outside contributors get a second, smaller path: PRs against existing code (docs included, blog posts not), and
image proposals for a labs org. It is written out here, but it matters less for now.

The harness sits beside the workspace; it does not replace it. The workspace stays the uncaged
rapid-development repo for broad changes. The harness is the guided way in.

This plan comes from four research passes over every repo in `repos/` and the live org (2026-10-27), plus the
maintainers' answers to its first draft.

## Settled for this harness

| Question | Answer |
| --- | --- |
| Roles | Two. A **member** is an org member; in the playground, every member is an owner with no limits. A **contributor** is anyone else. LinuxServer's tiers (developers, support…) are out of scope. |
| Labs org | `linuxserver-playground-labs` for the demo. Sub-orgs for the live cutover come later. Add it to `docs/playground-references.md` (production: `linuxserver-labs`). |
| Workspace | Stays as it is. The harness does not move its files. It links to `repos/workspace/DECISIONS.md` and `docs/` (bootstrap clones the workspace like any other repo). The org profile README and the org description point newcomers at the harness, not the workspace. |
| How members change things | They create new repos at will and put the initial content up as a PR. Changes to existing repos go through a PR that someone reviews. This is a convention steered by the harness, not enforced by rulesets. |
| Contributors | PRs against existing code, docs pages included. No blog posts. New images go through labs. |
| Agent review | Manual and local. A member asks their own agent to review or explain; nothing runs automatically in CI. Something like pullfrog may come later. |
| Where it runs | On the member's own machine, with Docker, so images can be built, run and compared locally. |

## Principles

1. **Scripts decide, prose explains.** A shell CLI, `./harness`, does the parts that must give the same result
   every time: detecting the role, cloning, forking, validating, gathering data and drafting a PR. Any agent
   that reads `AGENTS.md` behaves the same, not only Claude Code. The guides tell the agent when to call it
   and why.
2. **One source of truth per fact.** The harness links to `CONVENTIONS.md`, the per-repo `AGENTS.md` files,
   the schemas, and the workspace's `DECISIONS.md` and `docs/`. It does not copy them. It owns only the guided
   layer: the role briefing, the request table, the guides, the data recipes and the PR contract.
3. **A person opens every issue and PR and posts every review.** `dot-github/CONTRIBUTING.md` says fully
   autonomous agents must not open PRs or issues. The agent drafts; the person reads the draft and approves
   the `gh issue create`, `gh pr create` or `gh pr review` call. These commands are never allowlisted, so
   they always prompt.
4. **Evidence travels with the work.** Every PR body carries a fixed block an agent can parse: intent, repos
   touched, effects on other repos, the validation commands and their results, and AI use. A reviewer's agent
   checks those claims instead of redoing the work.
5. **Test locally before saying it works.** The harness assumes Docker. A fix is not done until the image has
   been built and run locally, or the PR says plainly that it was not.

## What exists today

### Membership

- `gh api user/memberships/orgs/linuxserver-playground` returns `state: active` for a member and 404 for
  anyone else. Control makes the same check (`control/control/auth.py`). The call needs `read:org`, which
  `gh auth login` grants by default; a token without it gets 403.
- Every membership is private, so the public members list is no use.
- `gh api repos/<org>/<repo> --jq .permissions` works for anyone and answers "push, or fork?".
- The org has no teams, CODEOWNERS, branch protection or rulesets. With everyone an owner, the harness's
  guard hook is the only steer towards PRs. That is acceptable for the playground.

### Read-only data (no credentials)

| Source | What |
| --- | --- |
| `ci.thelamer.duckdns.org:8443/api/{status,fleet,runs,queue,pulls,issues,releases,scheduler,skips}.json` | Live fleet, runs, queue, scheduler decisions, every open PR and issue across the org with build and review state |
| `…/api/images/{name}.json`, `/api/builds/{owner}/{repo}/{run}.json` | State per image and per build |
| `linuxserver-playground.github.io/hub/openapi.json` | The authoritative endpoint list |
| `…/hub/api/v1/catalog/{name}.json`, `…/builds.json`, `…/builds/{tag}/{report,tests,diff,vulns,packages.<arch>}.json` | Image detail, build history, tests, package diffs, vulnerabilities |
| `…/hub/api/v1/{images,mods,packages,categories,stats,changelog}.json`, `packages/{pkg}.json`, `fleet/{bases,staleness}.json` | Fleet-wide views: which images ship a package, which build FROM a base, which are stale |
| `…/hub/builds/<image>/<tag>/` | Screenshots, `container.log`, file trees |
| `gh run/issue/pr/release`, `gh search issues/prs --owner linuxserver-playground` | Logs, history, search |

These answer most "what is going on" questions without opening a single repo. The member actions (rerun,
cancel, dispatch, skip) need control's browser session. The agent links to the fleet page for those, or uses
`gh workflow run` (members have write).

### Contribution mechanics the guides depend on

- **Image repos.**
  - A PR build runs in PR mode. A fork build gets a read-only token and no secrets.
  - `pr-report.yml` posts one comment: tests, screenshots, package diff, log tails.
  - `safe-to-publish` pushes `untrusted-pr/<name>:pr-<n>-<sha>`. A member's same-repo branch publishes
    there without the label.
  - Editable: both Dockerfiles, `root/**` and `image.yml` (a changelog entry for any Dockerfile or `root/`
    change). Generated files are off-limits.
  - Local validation: `builder check --drift warn` in the public builder image, shellcheck, exec bits,
    `docker build` per arch, and the ci harness's "Local usage" (the same test the PR gets).
- **Mods.**
  - One branch per mod. A new mod's branch is created from `template` by a member.
  - Validate with `tools/check-branch.sh` and `tools/test-mod.sh`.
- **Site, hub, control.** PR checks run on `pull_request` with no secrets. Site CI skips the overflow,
  editor-check and fleet-check scripts, so the author runs them locally.
- **Builder** has no PR checks, and a merge ships `builder:latest` to the whole fleet immediately.
- **Commits.** CONVENTIONS §8 forbids trailers, AI co-author lines included. The harness's
  `.claude/settings.json` must turn off Claude Code's commit attribution. AI use goes in the PR body instead.

## Repo layout

```
harness/
  AGENTS.md             Start here: run ./harness whoami, read your role guide, then the request table
  CLAUDE.md             @AGENTS.md
  README.md             For people: what this is, the three commands to start, example prompts
  harness               Bash CLI, shellcheck clean
  guides/
    start-here.md       The tour: what you can ask, with 20 example prompts per area (below)
    system-map.md       Repos, data flow, how a change goes live, in more depth than the workspace's
    data-sources.md     The data table, with example queries and jq recipes
    rules.md            Commits, the PR contract, generated files, namespaces, secrets, AI disclosure
    local-testing.md    Docker: build both arches, run, compare with the released tag, run the ci harness
    roles/member.md     Everything a member can do, and what still goes through a PR
    roles/contributor.md  The fork flow, what is out of reach and the right channel for it
    playbooks/          One per kind of request (below)
    gotchas.md          Lessons from the workspace history: the live-branch rule, first-push dispatch, the 20-job cap…
  templates/
    pr-body.md, issue-bug.md, issue-feature.md, proposal-image.md, change-train.md, review.md, triage-report.md
  .claude/
    settings.json       Read-only allowlist, deny list, hooks, commit attribution off
    hooks/session-start.sh   Runs ./harness whoami and puts the role briefing into context
    hooks/guard.sh      PreToolUse: stops commands that are wrong for the role, says why and what to do instead
    skills/<playbook>/SKILL.md   Thin wrappers that load guides/playbooks/<playbook>.md
```

Playbooks are plain Markdown in `guides/` so every agent can read them. The Claude skills only point at them.

## The `./harness` CLI

| Command | Does |
| --- | --- |
| `whoami` | Checks `gh auth status` and the scopes, then reads the membership. `active` means member. `pending` means contributor until the invite is accepted, and it says so. 404 means contributor. 403 suggests `gh auth refresh -s read:org`. Writes `.harness/profile.json` (gitignored) and prints the briefing. |
| `doctor` | Checks git, gh, docker with buildx (and qemu for the other arch), Python 3.13, Node 24, shellcheck and cargo. Says what is missing and which requests that rules out. |
| `core` | Clones the core set: builder, workflows, ci, hub, site, control, dot-github, workspace, docker-mods (single branch). |
| `get <repo>…` | Clones on demand with `--filter=blob:none`. For a contributor, it forks on first write (`gh repo fork --remote`: origin is the fork, upstream is the org). |
| `all` | Today's bootstrap behaviour: every repo. Members only, for fleet-wide changes. |
| `sync` | Fast-forwards every clone. Reports repos that were deleted or archived and stale directories. Never merges over local changes. |
| `setup [repo]` | Dev environments for only the repos you touch. |
| `validate [repo]` | Runs that repo's validation list from its `AGENTS.md`. Writes `.harness/validation/<repo>.md` for the PR body. |
| `render [repo]` | Runs the builder container against a checkout (`check`, then `render`). When the hub preview tool exists ([live-cutover.md](live-cutover.md)), `preview` joins it. |
| `try <image> [tag]` | Pulls and runs a released, `dev/` or `untrusted-pr/` tag locally with sensible volumes and ports, waits for `[ls.io-init] done.`, and prints the URL and the log tail. Also compares two tags (package diff from the hub, a side-by-side run). |
| `snapshot` | One JSON file of the org's current state (control's fleet, pulls, issues, runs, queue, plus hub status) for the triage playbooks, so the agent reasons over one consistent picture. |
| `lookup <image>` | A one-shot summary: live branches, last build, tests, open PRs and issues, drift, dependents (images that build FROM it). |
| `draft pr` / `draft issue` / `draft review` | Fills `templates/` from the branch, diff, validation file and profile into `.harness/drafts/`, for the person to read first. |

## Roles and steering

1. **SessionStart hook.** Runs `./harness whoami`. It puts the role, the login, what the role can do and the
   request table into context. A role older than 24 hours is checked again. Agents without hooks get the same
   from the first line of `AGENTS.md`: "Run `./harness whoami` before anything else and follow the guide it
   names."
2. **Guard hook (PreToolUse on Bash).**
   - **Members:**
     - Free: creating repos and pushing to a new repo's default branch while it holds only the initial
       scaffold.
     - Refused, with the reason and the PR command: `git push` to the default or live branch of an existing
       repo, and `push -f` outside your own branches.
     - Allowed only inside the playbook that sets a marker: moving `v1` (release-workflows) and deleting
       repos or packages (remove-image).
   - **Contributors:** refused, with the right channel named: `gh repo create`, `gh workflow run`, pushes to
     any `linuxserver-playground` remote, tag moves, package deletion. GitHub would reject these anyway; the
     hook explains why before they fail.
   - **Everyone:** no writes to `linuxserver/*`, no printing secrets.
3. **Settings.**
   - Carried over from the workspace: the read-only allowlist (gh, git, linters, `curl` to control and
     Pages, plus `./harness` read commands, `docker ps/logs/inspect`) and the `linuxserver/*` denies.
   - Commit attribution is off.

The role is a steer, not security. GitHub's permissions are the enforcement.

## What a member can ask: the playbooks

The agent sorts the request into one of the rows below and follows that playbook. A request that fits no row is
answered directly, or the agent offers to draft an issue in `harness`.

### Understanding and managing the org (the core of the demo)

| Playbook | Request | What the agent does | Output |
| --- | --- | --- | --- |
| `open-prs` | "What PRs are open? What needs me?" | `snapshot`, then every open PR with build status, report verdict, review state, age, author, size, and repos it is waiting on. Ranks by: blocks a release, red live build, waiting on review, stale. | A ranked table with one line of reasoning each, and links |
| `triage-issues` | "Prioritise the issues" | For every open issue: blast radius from the hub (how many images and live branches, dependents through `fleet/bases.json`), user-facing or internal, regression or long-standing, security, effort. Proposes a priority, a label and an owner area. | A ranked table, then on approval the label or comment calls, one prompt each |
| `explain` | "Explain this bug / PR / red build to me" | Reads the thread, the build report and logs, the code paths in the cloned repos, and the relevant CONVENTIONS and DECISIONS. Runs `docs/build-failure-triage.md` for a red build: upstream rot, network flake or pipeline bug. Reproduces with `try` where it can. | Plain-language explanation: what happens, why, who is affected, consequences of fixing it and of not fixing it, fix options with cost |
| `consequences` | "What breaks if we change or merge X?" | Ripple analysis: the change train order, schema and `contracts_version` impact, which images rebuild (a base image or builder template change touches the whole fleet), effects on the hub API and site, the 20-job runner cap for mass rebuilds. | A risk summary with a recommendation |
| `review` | "Review PR #n" | Parses the contract block. Checks out the head and runs `./harness validate`. Builds and runs the image locally, and compares it with the released tag (`try`). Checks the rules: generated files untouched, both Dockerfiles in step, changelog entry, s6 headers and exec bits, no foreign namespaces, train order. Reads the report comment. | `templates/review.md` draft: verdict, findings with file and line, what was tested locally; posted on approval |
| `fleet-health` | "How is the fleet?" | The workspace's `fleet-status`, extended: red live branches grouped by cause, stuck runs, upstream drift, staleness, queue against the 20-job cap. | A summary with suggested actions |
| `whats-new` | "What changed this week?" | Merged PRs, releases, decisions recorded in workspace commits, hub changelog. | A digest |

### Changing things

| Playbook | Member | Contributor | Output |
| --- | --- | --- | --- |
| `report-bug` | yes | yes | Issue draft. Runs the CONTRIBUTING decision ladder first (upstream? environment? mod? image?) and attaches evidence: build page, tests, logs, package diff. |
| `fix-image` | branch + PR | fork + PR | PR to the live branch, with `validate` output and a local run |
| `mod` | edit, or create the branch from `template`, then a PR | PR to an existing mod's branch; a new mod by issue | PR, or issue |
| `new-image` | new repo + PR (below) | labs proposal (below) | Repo + PR, or proposal |
| `docs` | PR, or the site editor; new sections too | PR to existing sections | PR with check, build, a11y and overflow output |
| `blog` | the site editor, or a PR | not available | PR |
| `site` | PR (with editor-check or fleet-check when relevant) | bug-fix PRs | PR |
| `hub` | PR with fixture updates | generator bug fixes | PR |
| `contract-change` (`image.yml` field, `record.json`, API shape) | change train (below) | issue describing the need | Tracking issue + linked PRs |
| `pipeline` (workflows, ci, builder) | PR, then `release-workflows` after merge | issue, or a bug-fix PR | PR |
| `fleet-ops` (dispatch, skip, hub refresh, remove an image) | the workspace commands, wrapped | not available; the agent says who to ask | Action + report |

### Member: a new image

1. Check for duplicates: hub `images.json`, the labs org, open proposals.
2. Create `linuxserver-playground/docker-<name>` with a blank default branch holding only a placeholder
   README.
3. Do all the work on a branch:
   - `builder migrate`, or the template for a non-LinuxServer app;
   - `builder render`, then `builder check`;
   - the hand-finish list;
   - the playground FROM rewrite.
4. Build and run the image locally with `try`.
5. Open the PR for team review. Merging it releases the image.

Two pipeline details for this first PR are on the cutover list
([live-cutover.md](live-cutover.md#contribution-pipeline-gaps)): the generated-file guard, and
`pr-report.yml` on the blank default branch. Until they are fixed, the playbook says what to expect.

### Member: the change train

A cross-repo change follows the order in the workspace's `AGENTS.md` (builder, then hub, then site, then
control), run as a process:

1. One tracking issue in `harness` (`templates/change-train.md`). It lists the ordered PRs, what each one
   unblocks, and the `contracts_version` bump: MINOR for additive changes, MAJOR for renames and removals.
2. Each PR carries a `Train: harness#N, step k of n` line.
3. Merges happen in order. Hub CI installs `builder@main`, so the hub PR stays red until builder merges. The
   train says so.
4. The playbook checks that the site's `hub.ts`, the hub's models and the fixtures move together.

### Contributor path (secondary for now, written out)

- **Session start.** `whoami` says "contributor" and explains the fork flow. `get` forks on first write.
- **Bug reports and fixes.** Same playbooks as a member, through forks. The PR waits for a maintainer to
  approve the fork's workflow run. The report comment arrives after that. A pullable image needs
  `safe-to-publish`. The guide explains all three waits, so nobody thinks the PR is stuck.
- **Docs.** PRs to existing sections. No new sections, no blog posts.
- **New image (labs).**
  1. The agent fills `templates/proposal-image.md`: upstream and licence, why LinuxServer, architectures,
     ports and volumes, how versions are tracked, GUI or not, who will maintain it, duplicate check.
  2. Optionally, it scaffolds a v2-layout repo in the contributor's own account and validates it locally, so
     the proposal shows something that runs.
  3. The proposal goes to `linuxserver-playground-labs` as an issue (in a `proposals` repo there). The
     contributor's repo is transferred or forked into labs once accepted.
  4. Graduation from labs to the main org is a member running `new-image` from the labs repo.
  5. The playbook marks what is not settled yet: who reviews, the labs build namespace, the graduation
     criteria.
- **New mod.** An issue asking for the branch, with `mod.yml` filled in.

## The PR contract

`templates/pr-body.md` keeps the existing checkboxes from `dot-github/.github/PULL_REQUEST_TEMPLATE.md` and
adds one block for the reviewer's agent:

```
<!-- harness
intent: fix-image
role: member
harness: 0.1.0
repos: [docker-sonarr]
issue: linuxserver-playground/docker-sonarr#12
train: none
ripple: none
generated_files_touched: false
changelog_entry: true
validation:
  - builder check --drift warn: ok
  - shellcheck root/: ok
  - docker build amd64: ok; ran locally, web UI answered 200, [ls.io-init] done
  - docker build arm64: not run (no arm64 builder)
ai: Claude Code (claude-opus-5-5) drafted the change; the author read every line and ran the image
-->
```

The block sits under prose describing what changed, why, and how it was tested. Issues get the same block with
intent, image or repo, build tag and evidence links. "Not run" is fine. Claiming a run that never happened is
not.

## Before the demo

The harness should not wait on pipeline polish. Gaps that matter for real contributors are tracked in
[live-cutover.md](live-cutover.md). Two things are worth doing first:

- **Close the `[test data]` issues and PRs** in docker-heimdall and docker-bookstack (workspace #3). They
  would skew every `open-prs` and `triage-issues` answer.
- **Point the org profile README and description at the harness.**

## Testing the harness

The canned requests below run per role in a fresh clone: a member account, and an outsider account for the
contributor path.

| Request | Expect |
| --- | --- |
| "What PRs are open and which first?" | A ranked table from the snapshot; nothing filed |
| "Prioritise the issues" | A ranking with blast radius; label calls prompt one by one |
| "sonarr's arm64 build is red: explain it and what happens if we leave it" | Triage verdict, consequences, a local reproduction attempt |
| "Review docker-heimdall PR #n" | Validation re-run, local run, a draft review, nothing posted without approval |
| "Add an env var to heimdall to change X" | Branch or fork, changelog entry, validate, local run, PR draft |
| "Add image Y" | Member: repo + PR. Contributor: labs proposal |
| "Write a blog post about Z" | Member: editor or PR. Contributor: declined, with the reason |
| "Add a `homepage` field to image.yml and show it on the site" | Member: change train. Contributor: an issue |
| "Move v1" / "delete docker-foo" | Member: only through the playbook. Contributor: refused, with the right channel |

What to check on each run:

- Was the classification right?
- Were refusals explained?
- Was `validate` run and reported honestly?
- Does the contract block parse?
- Were only allowed files touched?
- Was anything filed or posted without approval?

Results go in the harness's `docs/evals.md`.

## Phasing

| Phase | Scope | Done when |
| --- | --- | --- |
| 1 | The member core: `whoami`, `doctor`, `core`/`get`/`sync`, `snapshot`, `lookup`, `try`, the hooks, `start-here.md`, the playbooks `open-prs`, `triage-issues`, `explain`, `consequences`, `review`, `fleet-health` | A team member, in a fresh clone, gets a ranked PR list, an explained bug with consequences, and a locally tested review draft |
| 2 | Member changes: `fix-image`, `new-image` (repo + PR), `docs`, `blog`, `site`, `hub`, `mod`, `contract-change` trains, `pipeline`, `fleet-ops`, the PR contract | A member takes a three-repo field change through a train, and the `review` playbook catches a planted rule break |
| 3 | The contributor path: forks, the labs org and `proposals` repo, the proposal template, contributor evals | An outsider account turns "fix X in image Y" into a fork PR with a parseable contract |
| 4 | Evals as routine, harness versioning. Automated review is on the cutover list | Regressions show up before people hit them |
