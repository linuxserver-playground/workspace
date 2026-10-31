# Build failure triage: ours, upstream's, or the network's

A red build in the playground has one of three causes. First, upstream's source was already broken: the
playground builds the same Dockerfile LinuxServer.io's Jenkins does. Second, the network flaked. Third, the
pipeline itself is wrong. Only the last is ours to fix. Find out which it is before you spend time on it.

## 1. Find the failing step

```bash
gh run view <run> -R linuxserver-playground/docker-<name> --json jobs \
  -q '.jobs[] | select(.conclusion=="failure") | .name + ": " + ([.steps[] | select(.conclusion=="failure") | .name] | join(","))'
gh run view <run> -R linuxserver-playground/docker-<name> --log-failed | grep -B12 'Process completed with exit code'
gh run view <run> -R linuxserver-playground/docker-<name> --log | grep -E 'curl: \(|E: |apk: |ERROR: failed to solve|no match for platform'
```

Grepping for `ERROR` alone misleads, because package names like `liberror-perl` match. The lines just before
`Process completed` are usually the real reason, but a buildx `RUN` that failed on a download prints the cause
(`curl: (28) Failed to connect to downloads.scummvm.org port 443`, 2026-10-31) forty lines above the marker, after
the Dockerfile echo: the second grep finds it.

## 2. Is the source already broken upstream?

The playground's converted branch is one commit on top of upstream's branch head. Check that upstream has not
moved, then read Jenkins's status on that commit. These are read-only GETs; `linuxserver/*` is never written to.

```bash
git -C repos/docker-<name> remote add upstream https://github.com/linuxserver/docker-<name>.git 2>/dev/null  # the harness adds it as `linuxserver`
git -C repos/docker-<name> fetch -q upstream
git -C repos/docker-<name> rev-list --count <branch>^..upstream/<branch>    # 0: same source as ours
gh api repos/linuxserver/docker-<name>/commits/<branch>/status -q '.state + " " + (.statuses[0].updated_at // "-")'
gh api repos/linuxserver/docker-<name>/commits/<branch> -q .commit.committer.date
```

- `failure`: Jenkins fails on the same commit, so it is upstream's problem. Note it and move on.
- `pending` with no status, on an old head: Jenkins never built that commit. Treat the branch as stale upstream.
- `success`, recent, with the same source: the cause is ours or the network's. Keep going.
- `success` but older than a helper image the Dockerfile pulls: the rot is in that image, and Jenkins has simply
  not built since. `no match for platform in manifest: not found` on a `FROM` that is only used for `COPY --from`
  (tvheadend's `ghcr.io/linuxserver/picons-builder`, 2026-10-30) means the helper is published for one
  architecture, and buildx, which asks for the target platform, refuses what the classic builder accepted. A
  plain single manifest (no platform list) passes on any architecture; the moment the publisher's `docker build`
  starts attaching provenance, the same image becomes an index with one platform, and every other-arch build that
  pulls it breaks. Remedy: `FROM --platform=linux/amd64 <image>` for a stage that only supplies files (the one
  that would work on Jenkins too), or the publisher builds the files once and pushes a multi-arch index
  (`FROM --platform=$BUILDPLATFORM` for the builder stage, `--platform linux/amd64,linux/arm64` for the `scratch`
  final stage).

## 3. Rerun once if it looks like the network

Control already re-runs a live build once by itself when every failed job failed on an infrastructure step
(checkout, GHCR login, artifacts, publishing tags, the release, the events POST), and retries a failed Pages
deploy with backoff (control README, "Self-healing"; its retries show on `/management` and as `heal` decisions on
`/scheduler`). It never re-runs a failure inside the image build or the tests, because it cannot tell a network
blip in a Dockerfile's `RUN` from upstream rot. Those are yours:

```bash
gh run rerun <run> -R linuxserver-playground/docker-<name> --failed
```

These cleared on a rerun:

- GHCR `token ... EOF`;
- `curl: (22) ... 502`;
- `curl: (28) Failed to connect to <the project's download host> port 443` when the host answers again minutes
  later (scummvm, 2026-10-31);
- uv or pip `Failed to download`;
- apk `unable to select packages`, for packages that exist. Check with
  `docker run --rm <base> apk add --no-cache <pkg>`.

If the same network-shaped error comes back twice, it is not a flake.

When GitHub itself is degraded (check `https://www.githubstatus.com/api/v2/incidents/unresolved.json` first), read
`docs/github-outage-2026-10-30.md` before touching anything: it lists what control repairs on its own during an
incident, how long each repair takes, and what only looks broken.

## 4. Signs that the pipeline is at fault

- It fails in one of our steps, not in the Dockerfile's `RUN`: prepare (manifest, version, shellcheck and s6
  permissions), Test (the ci harness) or Publish.
- Several unrelated images fail at the same step.
- Upstream is green on the same commit.

Fixed so far, as examples:

| Signature | Cause |
| --- | --- |
| `Init graph: FAIL ... image has no /etc/s6-overlay/s6-rc.d` | The harness failed non-s6 images. It skips them now. |
| `tests are disabled` never shown, and tests fail with `test.enabled: false` | jq's `//` read `false` as missing. |
| `MANIFEST_JSON: parameter null or not set` and `Skip output 'manifest_json' since it may contain secret` | A masked value inside a job output. The manifest is an artifact now. |
| `command source failed (23)` | curl's write error from an early-exiting `grep -m1`. Now accepted, like SIGPIPE. |
| `Error response from daemon: manifest unknown` right after `pushing manifest` in Build | GHCR's read-after-write delay. The post-push pull retries it now. |

Fix it in the repo that owns the step (workflows, ci, builder or control), then prove it with a rebuild of the
images it broke. Record what you found in `conversion-report.md` when it came from staging.

## 5. Write it down, not up

For upstream rot, do not patch the Dockerfile in the playground: the image repo would drift from the
original. Record a one-line reason in `conversion-report.md` and leave the branch red until upstream fixes it.
