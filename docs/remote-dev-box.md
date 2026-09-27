# Oracle as remote coding-agent dev box (investigation #166)

Investigated 2026-09-26; **implemented and verified 2026-09-27**. All numbers
measured from the live host or from Oracle's published Always Free docs.

**Verdict: yes — and it is now live.** The A1 VM is the default remote dev box
at **£0/month incremental**: Docker cleaned, 150 GB block volume attached as
`/workspace`, toolchain + agent CLIs installed, `agent@.service` +
`issue-dispatch.timer` running, reboot and e2e dispatch verified.

## Measured live state (2026-09-27, post-implementation)

| Metric | Before (26th) | Now |
|---|---|---|
| CPU / RAM | 2 OCPU A1, 11 GiB, no swap | same, plus **4 GB swapfile** |
| Boot disk | 48 GB, 74% used | 48 GB, **27% used** (35 GB free) |
| Workspace | none | **150 GB block volume** at `/workspace` (138 GB free) |
| Docker | 32 GB reclaimable inside `/var/lib/containerd` | **0 images/0 cache**, data-root `/workspace/docker`, json-file log rotation (10 MB × 3) |
| journald | uncapped | capped `SystemMaxUse=100M` (66 MB) |
| Dispatcher | Mac launchd only (broken codex path) | **`issue-dispatch.timer` on Oracle (60 s), e2e verified** |

Idle services: journald 176 MB, hermes-dashboard 142 MB, dockerd 127 MB,
containerd 68 MB, tailscaled 42 MB (RSS).

## Free-tier allowance (verified from Oracle docs)

- **Compute:** A1 Always Free = 1,500 OCPU-hrs + 9,000 GB-hrs/month = a
  continuous **2 OCPU + 12 GB**. This tenancy is **fully allocated** to the
  single VM — no £0 second VM and no resize headroom.
- **Storage:** 200 GB combined boot+block volume pool. Boot volume is 50 GB
  (48 GB usable) → **150 GB block volume now attached at £0** (created via OCI
  CLI, paravirtualized attach, ext4, mounted `/workspace` by UUID with
  `nofail`; minimum block volume 50 GB; five backups included and free).
- **Idle reclamation:** Oracle may reclaim an A1 instance if over a 7-day
  window the 95th-percentile CPU < 20%, network < 20%, **and** memory < 20%.
  Real agent activity clears this easily; the risk applies only to a box left
  untouched for weeks.

## Tool compatibility (repo-development subset)

**Works natively on linux-arm64 (all installed 2026-09-27):** git, gh (token +
`gh auth setup-git` credential helper), **Node v24.21.0** (tarball at
`/usr/local/lib/nodejs`, symlinked into `/usr/local/bin`), npm 11.19, Python3,
uv, Docker + compose, **Playwright 1.63.0 with chromium + firefox arm64
builds** (942 MB under `/workspace/playwright`, headless launch verified),
tmux, GitHub Actions self-hosted runner (linux-arm64 asset), and the
coding-agent CLIs **codex 0.157.1, opencode 1.18.32, @cline/cli 0.0.13**.
Note: `@cline/cli`'s binary is named **`clite`**.

**Auth:** `~/.codex/auth.json` (ChatGPT subscription) and
`~/.local/share/opencode/auth.json` (OpenRouter) were copied from the Mac;
renew them there and re-copy. The Mac's local `cliproxyapi` proxy is not
replicated, but the VM codex now has an **OpenRouter provider** in
`~/.codex/config.toml` whose auth is pulled live from `~/.hermes/.env` (no key
copy) — verified: `codex exec -c model_provider=openrouter -m
z-ai/glm-5.3-flash` answers over the responses wire.

**Needs adaptation:** nvm's installer fails on the VM (tarball used instead).
browser-relay/Playwriter run in the Mac's Chrome — a remote agent can drive
them over Tailscale but only while the Mac is awake, so keep those workflows
on the Mac.

**Mac-only:** the `omp` CLI (Mach-O arm64 binary; dropped from the VM
dispatcher config) and anything needing the macOS GUI/Keychain.


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

- `/workspace` (block volume) holds: repos (`/workspace/Code`), worktrees
  (`/workspace/codex-worktrees`), npm/uv caches (`/workspace/cache`), Playwright
  browsers (`/workspace/playwright` via `/etc/environment`), Docker data-root
  (`/workspace/docker`). Agent session state lives in `/workspace/agents`.
- ✅ Done 2026-09-27: Docker images + build cache pruned (+29 GB); journald
  capped at 100 MB; Docker json-file log rotation set.
- Worktrees: `<repo>/<branch>` under `/workspace/codex-worktrees` (per the
  dispatcher's rig-worktree flow); prune worktrees/branches whose PR merged
  > 7 days ago; test traces/screenshots/videos retained 7 days.
- Disk pressure: **enforced** by `/usr/local/bin/workspace-disk-guard.sh` +
  `workspace-disk-guard.timer` (every 6 h + 5 min after boot): ≥80% `/workspace`
  → npm/uv caches + docker build cache; ≥85% → + unused images; ≥90% → + stale
  worktrees (untouched 14+ days) removed via the parent clone. Runs as
  `ubuntu`; never touches `/workspace/agents`, the `/workspace/Code` clones
  themselves, `~/.codex`, `~/.hermes` or Tailscale state.
- **Never auto-delete:** agent session state/logs (`/workspace/agents`),
  `~/.codex` (auth + sessions), `~/.hermes`, `/var/lib/tailscale`, active
  repos' `.git`, the `workspace` volume's filesystem.

## Long-running execution architecture (implemented)

- **`agent@.service`** (system template, `/etc/systemd/system/agent@.service`):
  runs `/workspace/agents/<name>/job.sh` as `ubuntu` with the workspace env
  (Playwright/cache paths), `Restart=on-failure` + `RestartSec=5` — survives
  SSH drops, crashes (verified: SIGKILL of the main process → NRestarts=1 →
  recovered) and reboots. For interactive attach, tmux inside the job.
- **Dispatcher migrated:** `~/issue-dispatch/` on the VM holds
  `issue-dispatch.py` + a Linux `run-dispatch.sh` + `dispatch-config.json`
  (harnesses: `agent:codex`, `agent:opencode`, `agent:clite`; `agent:omp`
  removed — Mac-only; clone/worktree roots retargeted to `/workspace`).
  `rig-worktree.sh` at `~/.codex/scripts/`. Enabled as
  **`issue-dispatch.timer`** (OnUnitActiveSec=60, OnBootSec=60, persistent).
  End-to-end verified on codex-home#167: poll → claim → auto-clone →
  worktree → codex exec (10 s, resumable session id) → `agent:done`.
- **The Mac LaunchAgent is unloaded** (only to keep one active dispatcher
  initially — routing now makes running both safe; flock is per-machine, and
  `box:` labels decide ownership). Rollback:
  `launchctl load ~/Library/LaunchAgents/com.rajeev.issue-dispatch.plist`
  (after fixing the Mac codex path, see below).
  Note: the Mac config's codex binary path
  (`/Applications/ChatGPT.app/Contents/Resources/codex`) is broken after a
  ChatGPT.app update — fix it before re-enabling Mac dispatch.
- **Reboot verified 2026-09-27:** after `systemctl reboot`, `/workspace`
  mounted (nofail fstab), swap active, Docker data-root correct, timer +
  hermes-dashboard active.
- **Self-hosted Actions runner fleet:** registered to Rajeev-SG/codex-home
  (`/workspace/actions-runner-codex`) and to **12 private repos**
  (`/workspace/runners/<repo>`, labels `self-hosted, Linux, ARM64, oracle`;
  14 systemd services total, all enabled). All private-repo workflows were
  switched from `runs-on: ubuntu-latest` to `[self-hosted, arm64]` (PRs merged
  2026-09-27) — private CI now costs **£0 in hosted minutes** and runs on this
  box. Public repos stay on free GitHub-hosted runners (fork-PR safety).
  Point ARM CI jobs at `runs-on: [self-hosted, arm64]`.

## Dispatching a task to the box

The box watches **Rajeev-SG/codex-home** issues (`issue-dispatch.timer`, poll
every 60 s; one dispatcher per box — routing keeps hosts out of each other's
way). To give it a task:

1. **Create or label an issue in `Rajeev-SG/codex-home`** (only issues authored
   by `Rajeev-SG` are accepted).
2. **Put a `repo:` hint line in the body** — the repo where the work happens
   (e.g. `repo: Rajeev-SG/oracle-vps`). The dispatcher auto-clones it into
   `/workspace/Code` and creates a worktree + branch `gh-<issue>-<slug>` under
   `/workspace/codex-worktrees`.
3. **Add two labels:** `agent:queued` + exactly one harness label —
   `agent:codex`, `agent:opencode`, or `agent:clite`.
4. Within ~60 s the box claims it (`agent:queued` → `agent:running`,
   atomic label move), builds the prompt from the issue title + body + comments
   (≤ 100k chars), and runs the harness. Limits: 6 h per run, 30-min idle
   timeout, 3 attempts. Failed provider runs resume from the recorded native
   session (codex/opencode) instead of starting over.
5. **Outcome:** a metadata comment lands on the issue (status, worktree,
   branch, session id, duration) and labels move to `agent:done` or
   `agent:failed`. GitHub stays the source of truth; worktrees are disposable
   and get reclaimed (guard: untouched 14+ days at ≥90% disk pressure; PR
   merged > 7 days per the retention policy).

Watch live: `gh issue view <n> -R Rajeev-SG/codex-home` for labels/comments, or
`ssh oracle 'journalctl -u issue-dispatch.service -f'`. Internals, retry/stale
sweep and safety model: [codex-home `scripts/issue-dispatch/README.md`](https://github.com/Rajeev-SG/codex-home/blob/main/scripts/issue-dispatch/README.md).

**Routing (codex-home#168):** any machine can run a dispatcher against the one
queue; `box:<name>` labels decide which host claims an issue. Add `box:oracle`
to target this box specifically; `box:mac` targets the Mac (the Oracle box
ignores it); no `box:` label → the host with `"default_box": true` (Oracle).
`try_claim` re-validates routing at claim time, so two hosts can never work
the same issue. If a claiming host dies mid-run:
`issue-dispatch.py --reset <n>` on any host returns the issue to the queue;
`--route <n>` reports which box owns it.

The Mac LaunchAgent is currently **unloaded** — Oracle is the only active
dispatcher. To move dispatch back to the Mac, fix the Mac codex path first
(see below), give the Mac config `"box": "mac"`, and unload the VM timer.

## Implementation log (2026-09-27, all verified live)

1. ✅ Docker pruned: 9.9 GB images + 19.3 GB build cache removed → boot disk
   74% → 25% (0 containers / 0 volumes existed, zero risk taken).
2. ✅ 150 GB block volume `workspace` created (OCI CLI), paravirtualized
   attached, ext4, mounted `/workspace` (fstab UUID, `nofail`).
3. ✅ Docker data-root → `/workspace/docker` (daemon.json, json-file log
   rotation); 4 GB swapfile `/swapfile` (fstab); journald `SystemMaxUse=100M`;
   `/etc/environment` sets `PLAYWRIGHT_BROWSERS_PATH`, `NPM_CONFIG_CACHE`,
   `UV_CACHE_DIR` into `/workspace`.
4. ✅ Node v24.21.0 + npm 11.19 installed; codex 0.157.1 / opencode 1.18.32 /
   clite 0.0.13 (`@cline/cli`) installed; Playwright 1.63.0 + chromium/firefox
   arm64 browsers (942 MB) with headless-launch test passed; codex smoke run
   OK ("OK-VM").
5. ✅ `agent@.service` installed; crash-restart (SIGKILL → NRestarts=1) and
   full reboot survival verified.
6. ✅ Dispatcher ported to `issue-dispatch.timer`; e2e verified (codex-home#167
   claimed, run, `agent:done`, resumable session); Mac LaunchAgent unloaded.
7. ✅ Disk-pressure guard implemented: `workspace-disk-guard.timer` (6 h) runs
   the 80/85/90% tiered cleanup (`/usr/local/bin/workspace-disk-guard.sh`).
8. ✅ Codex OpenRouter provider added to VM `~/.codex/config.toml` (auth read
   live from `~/.hermes/.env`); verified with a real run via
   `z-ai/glm-5.3-flash` → `OK-OPENROUTER`.
9. ✅ Self-hosted Actions runner installed: `oracle-vps-685146`, registered to
   Rajeev-SG/oracle-vps, labels `self-hosted, Linux, ARM64, oracle`, binaries
   + `_work` on `/workspace/actions-runner`, systemd service `enabled` and
   `online`.

**Monthly infra cost: £0** — everything stays within Always Free.
