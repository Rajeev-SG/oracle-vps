# Oracle as remote coding-agent dev box (investigation #166)

Recorded 2026-09-26. All numbers measured from the live host or from Oracle's
published Always Free docs. Investigation only — no infrastructure was changed.

**Verdict: yes.** The existing Oracle A1 VM can be the default remote dev box
for long-running coding-agent jobs at **£0/month incremental**, after a Docker
cleanup and a 150 GB block volume. Compute is the hard ceiling (tenancy is
already fully allocated); storage and tooling are not blockers.

## Measured live state (2026-09-26)

| Metric | Value |
|---|---|
| CPU | 2 OCPU Ampere A1 (aarch64), idle load 0.06 |
| RAM | 11 GiB total, 1.7 GiB used, 9.9 GiB available, **no swap** |
| Boot disk | 48 GB, 35 GB used (74%), 13 GB free |
| Largest consumer | `/var/lib/containerd` 28 GB (Docker images + build cache) |
| Reclaimable now | ~32 GB: 13.0 GB images (6, 0 in use) + 19.3 GB build cache (47 entries); 0 containers, 0 volumes |
| Idle services | journald 176 MB, hermes-dashboard 142 MB, dockerd 127 MB, containerd 68 MB, tailscaled 42 MB (RSS) |

After cleanup the boot volume has ~67 GB free; a 150 GB block volume takes
workspace growth off it entirely.

## Free-tier allowance (verified from Oracle docs)

- **Compute:** A1 Always Free = 1,500 OCPU-hrs + 9,000 GB-hrs/month = a
  continuous **2 OCPU + 12 GB**. This tenancy is **fully allocated** to the
  single VM — no £0 second VM and no resize headroom.
- **Storage:** 200 GB combined boot+block volume pool. Boot volume is 50 GB
  (48 GB usable) → **~150 GB block volume available at £0**, attachable to the
  same instance without touching the boot volume. Minimum block volume 50 GB.
  Five volume backups included; Always Free volumes and backups are free.
- **Idle reclamation:** Oracle may reclaim an A1 instance if over a 7-day
  window the 95th-percentile CPU < 20%, network < 20%, **and** memory < 20%.
  Real agent activity clears this easily; the risk applies only to a box left
  untouched for weeks. (This instance has run since 2026-09-16.)

## Tool compatibility (repo-development subset)

**Works natively on linux-arm64:** git, gh, Node (tarball), npm/pnpm, Python3,
uv, Docker + compose, Playwright (arm64 browser builds for Ubuntu 24.04),
Vercel CLI, tmux, GitHub Actions self-hosted runner (linux-arm64 asset), and
the coding-agent CLIs **codex, opencode-ai, @cline/cli** (all ship linux-arm64).

**Needs adaptation:** nvm's installer failed on the VM (use the Node tarball or
NodeSource apt); browser-relay/Playwriter run in the Mac's Chrome — a remote
agent can drive them over Tailscale but only while the Mac is awake, so keep
those workflows on the Mac.

**Mac-only:** the `omp` CLI (Mach-O arm64 binary) and anything needing the
macOS GUI/Keychain.


## Representative repo footprints (measured on the Mac)

| Repo | Total | .git | deps | build cache |
|---|---|---|---|---|
| rajeevg.com | 3.0 GB | 235 MB | 1.1 GB | .next 1.3 GB |
| agent-ops | 1.2 GB | 0.9 MB | 30 MB venv | — |
| gods-eye-view | 418 MB | 74 MB | 256 MB | — |
| automation-pareto-bench | 143 MB | 2.6 MB | 139 MB venv | — |
| 7 other small repos | < 40 MB each | ≤ 2.6 MB | — | — |

Plus Playwright browsers ~1.5–2 GB (chromium+firefox+webkit, arm64) and
npm/pnpm caches (keep ≤ 5 GB). **~10 active repos ≈ 10–12 GB steady state** —
12× headroom on the 150 GB volume. The Mac's 30 GB Projects folder is mostly
knowledge-work data; only the above subset is mirrored. Full clones (max .git
235 MB) make shallow/partial clones unnecessary.

## Measured performance

- Single-core bench 83 G-iter/s; two concurrent workers sustain 95.6 + 94.6
  G-iter/s per core — **no contention at 2 agents doing CPU-light work**.
- npm cold install (ts+zod+next15): 13.6 s. tsc: 1.6 s. Disk write burst 1.8 GB/s.
- One agent + build/test loop: comfortable. One Chromium E2E worker: fine.
- Two agents both building + browsing simultaneously: marginal — keep the
  existing **≤ 2 concurrent browser workers** rule (see architecture.md).
- Too heavy for this host: parallel multi-worker browser suites, multi-arch
  Docker builds, local LLM inference (never — API-based).

## Cleanup / retention policy

- `/workspace` on the block volume holds: repos, worktrees, npm/pnpm/uv
  caches, Playwright browsers (`PLAYWRIGHT_BROWSERS_PATH`), Docker data-root.
- Immediate: prune Docker images + build cache (+32 GB); cap journald at
  100 MB (`SystemMaxUse`).
- Worktrees: `<repo>/.worktrees/<issue>`; auto-prune worktrees/branches whose
  PR merged > 7 days ago; test traces/screenshots/videos retained 7 days.
- Disk pressure: 80% → prune caches + Docker build cache; 90% → prune stale
  worktrees + Docker images; stop starting new jobs.
- **Never auto-delete:** agent session state/logs (`/workspace/agents`),
  `~/.hermes`, `/var/lib/tailscale`, active repos' `.git`, volume backups.

## Long-running execution architecture

- One systemd user unit (`systemd-run --user` or an `agent@.service` template)
  per job, with tmux inside for interactive re-attach; `Restart=on-failure`
  survives both SSH drops and reboots. journald captures logs.
- Worktrees per issue; GitHub stays source of truth; workspaces disposable.
- The Mac's issue dispatcher (`~/.codex/scripts/issue-dispatch`, Python stdlib
  + flock + atomic GitHub label moves) ports as-is to a **systemd timer** on
  Oracle — no second orchestration system.
- Optional later: self-hosted Actions runner (linux-arm64) for CI on ARM.

## Implementation order (value/risk)

1. Prune Docker images + build cache on Oracle → +32 GB (zero containers or
   volumes exist, so zero risk).
2. Attach the 150 GB free block volume as `/workspace` (ext4, fstab).
3. Move Docker data-root, package caches and Playwright browsers to
   `/workspace`; add a 2–4 GB swapfile; cap journald.
4. Install Node tarball, gh, agent CLIs (codex/opencode/cline), Playwright
   arm64 browsers.
5. Run the first long job under tmux + systemd; verify it survives SSH drop
   and reboot.
6. Port the issue dispatcher to a systemd timer on Oracle.

**Monthly infra cost: £0** — everything stays within Always Free.
