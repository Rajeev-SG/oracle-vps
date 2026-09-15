# Hermes Agent on Oracle — install, access, recovery

Installed 2026-09-16 via the official installer.

- **Version:** Hermes Agent v0.21.3 (2026.9.14), install method git, updated via `hermes update`
- **Install layout:** code `~/.hermes/hermes-agent`, venv `~/.hermes/hermes-agent/venv`,
  managed Node `~/.hermes/node`, data `~/.hermes/` (sessions, memories, skills, logs)
- **Model:** OpenRouter, default `z-ai/glm-5.3-flash` (same workhorse as the Mac install);
  key stored in `~/.hermes/.env` (0600)

## What it can administer

- Full local terminal as `ubuntu` with passwordless sudo (`hermes chat` tools)
- Docker: `ubuntu` is in the `docker` group (docker 29.8.1)
- Hetzner over Tailscale SSH: `ssh jeev-hetz-1` (alias in `~/.ssh/config`)
- Coolify API: token at `~/.secrets/coolify-api-token` (see access doc)
- GitHub: `gh` authenticated as `Rajeev-SG`; git identity
  `Hermes (Oracle) <hermes@rajeevg.com>`
- Vercel: CLI authenticated as `rajeev-6969` (auth file, see access doc)

## Phone access (Android over Tailscale)

1. Turn on Tailscale on the phone (device `rajeevs-s22`).
2. Open **http://100.112.158.79:9119** (Oracle's Tailscale IP).
3. Log in with username `rajeev` and the dashboard password.
4. Use the **Chat** tab — it runs a real Hermes session with the full toolset.

- The dashboard binds **only** to the Tailscale interface. The public IP does not
  serve port 9119 (OCI security list + bind address), and basic auth is enforced
  for any non-loopback access.
- Dashboard password: stored on Oracle at `~/.secrets/dashboard-password`
  (`ssh oracle cat ~/.secrets/dashboard-password`). Hash + signing secret live in
  `~/.hermes/.env` so sessions survive restarts.

## Persistence

`hermes-dashboard.service` (systemd, enabled):

- Waits for the Tailscale IP, then runs
  `hermes dashboard --host 100.112.158.79 --port 9119 --no-open`
- `Restart=always`, `RestartSec=10`; runs as `ubuntu` with the `docker`
  supplementary group; no desktop session involved.

Logs:

```bash
ssh oracle 'journalctl -u hermes-dashboard -f'   # live
ssh oracle 'ls ~/.hermes/logs'                   # agent logs
# or just ask Hermes to show its own logs in chat
```

## Recovery

```bash
ssh oracle 'systemctl status hermes-dashboard'
ssh oracle 'sudo systemctl restart hermes-dashboard'
ssh oracle 'export PATH=$HOME/.local/bin:$PATH; hermes --version'
```

If the dashboard port is stuck: `sudo fuser -k 9119/tcp` then restart the unit.
If Tailscale is down: `ssh oracle 'sudo tailscale up --hostname oracle-vps'`
(approve the login URL from any signed-in browser).
If Hermes itself is broken: re-run the installer (idempotent),
`curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash -s -- --skip-setup`,
then `sudo systemctl restart hermes-dashboard`.

## Updating

```bash
ssh oracle 'export PATH=$HOME/.local/bin:$PATH; hermes update'
sudo systemctl restart hermes-dashboard
```

Pin note: `hermes update` pulls the latest stable; the installed commit is shown
by `hermes --version`. Update deliberately, restart the service afterwards.

## Healthcheck

```bash
curl -s http://100.112.158.79:9119/api/status | jq '.version, .auth_required'
```