#!/usr/bin/env bash
# workspace-disk-guard — tiered disk-pressure cleanup for the Oracle dev box.
# Policy (oracle-vps docs/remote-dev-box.md):
#   >=80% /workspace → package caches (npm, uv) + docker build cache
#   >=85% → + unused docker images
#   >=90% → + stale worktrees (untouched 14+ days) under /workspace/codex-worktrees
# NEVER touches: /workspace/agents (agent session state/logs), the clones in
# /workspace/Code (only linked worktrees are removed), ~/.codex, ~/.hermes,
# /var/lib/tailscale. GitHub is the source of truth; worktrees are disposable.
set -u
STALE_DAYS=14
pct() { df --output=pcent "$1" | tail -1 | tr -dc 0-9; }
WS=$(pct /workspace); ROOT=$(pct /)
echo "guard: /workspace=${WS}% /=${ROOT}%"

LEVEL=0
[ "${WS:-0}" -ge 80 ] && LEVEL=1
[ "${WS:-0}" -ge 85 ] && LEVEL=2
[ "${WS:-0}" -ge 90 ] && LEVEL=3
[ "$LEVEL" -eq 0 ] && { echo "guard: no action needed"; exit 0; }
echo "guard: tier $LEVEL actions starting"

npm cache clean --force >/dev/null 2>&1 || true
uv cache prune >/dev/null 2>&1 || true
docker builder prune -a -f >/dev/null 2>&1 || true
echo "guard: caches pruned"

if [ "$LEVEL" -ge 2 ]; then
  docker image prune -a -f --filter "label!=keep=true" >/dev/null 2>&1 || true
  echo "guard: unused images pruned"
fi

if [ "$LEVEL" -ge 3 ]; then
  for wt in /workspace/codex-worktrees/*; do
    [ -d "$wt" ] || continue
    if [ -z "$(find "$wt" -maxdepth 0 -mtime -${STALE_DAYS})" ]; then
      gitdir=$(sed -n 's/^gitdir: //p' "$wt/.git" 2>/dev/null)
      parent=""
      [ -n "$gitdir" ] && parent=$(dirname "$(dirname "$gitdir")")
      if [ -n "$parent" ] && [ -d "$parent/.git" ]; then
        echo "guard: removing stale worktree $wt (parent $parent)"
        git -C "$parent" worktree remove --force "$wt" 2>&1 | head -2
      else
        echo "guard: removing stale worktree dir $wt (no parent repo found)"
        rm -rf "$wt"
      fi
    fi
  done
  echo "guard: stale worktrees pruned"
fi
echo "guard: done — /workspace=$(pct /workspace)% /=$(pct /)%"