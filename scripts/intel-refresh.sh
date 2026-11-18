#!/usr/bin/env bash
# On-demand refresh for the two intelligence products (both otherwise run weekly).
#   sudo intel-refresh adpi   # Capability Explorer: crawl, then write/publish guides
#   sudo intel-refresh adi    # AI Discovery: acquisition, then field-guide writer
#   sudo intel-refresh all    # both, one after the other
# Each step runs as its normal systemd unit (same env, limits and failure alerts).
# The guide writer normally only runs in the 00:00-05:00 UTC window; an on-demand
# run passes --force through a transient unit with the same settings.
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run with sudo" >&2; exit 1; }

adpi() {
  echo "adpi: crawl"; systemctl start --wait adpi-run.service
  echo "adpi: guides"
  systemd-run --wait --collect --quiet --unit="adpi-guides-now-$(date +%s)" \
    -p Type=oneshot -p TimeoutStartSec=3h \
    -p After=docker.service -p Requires=docker.service \
    -p EnvironmentFile=/etc/claude-writer/env \
    -p Environment=ADPI_CALL_DEADLINE_S=1800 \
    -p "UnsetEnvironment=ADPI_CLAUDE_MODEL ADPI_VERIFIER_MODEL ADPI_CLAUDE_BIN" \
    -p OnFailure=adpi-alert@adpi-guides-now.service \
    /usr/local/sbin/adpi-guides --force
  echo "adpi: done"; cat /var/lib/adpi/status/guides-latest.json 2>/dev/null | head -c 600; echo
}

adi() {
  echo "adi: acquisition"; systemctl start --wait adi-run.service
  echo "adi: writer";      systemctl start --wait adi-writer.service
  echo "adi: done"
}

case "${1:-}" in
  adpi) adpi ;;
  adi)  adi ;;
  all)  adpi; adi ;;
  *) echo "usage: sudo intel-refresh adpi|adi|all" >&2; exit 2 ;;
esac
