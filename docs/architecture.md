# Architecture: Oracle / Hetzner / Vercel

Recorded 2026-09-16. Numbers are measured from the live hosts, not assumed.

## Placement rule

**Persistent/core → Hetzner. Disposable/compute-heavy/background → Oracle. Public web frontend/serverless → Vercel.**

## Oracle Always Free VPS — compute / worker / agent box

- Host: `oracle-vps-685146`, public `140.238.91.73`, Tailscale `100.112.158.79`
- ARM64 (aarch64), Ubuntu 26.04.1 LTS, **2 OCPU / 11 GiB RAM / 48 GB disk (15% used)**
- Role: Hermes Agent (always-on operator), Tailscale, Docker, crawling/scraping
  workers (changedetection.io, Crawl4AI/Playwright-style jobs), batch/background
  jobs, ingestion/extraction/normalisation.
- Inference is API-based (OpenRouter) — no local LLMs.
- CPU is the expected constraint; keep browser concurrency **≤ 2 concurrent
  Chromium workers** and measure before raising.
- Services currently running: `hermes-dashboard` (systemd, Tailscale-only). Docker
  daemon installed and healthy; no long-running containers yet.

## Hetzner VPS — small persistent/core services box

- Host: `jeev-hetz-1`, public `89.167.5.185`, Tailscale `100.109.237.19`,
  cx23 (2 vCPU / 3.7 GiB RAM / 38 GB disk), eu-central hel1-dc2, Ubuntu 24.04.
- Role: Coolify control plane + persistent services only.
- ⚠️ **Disk is 93% full (34G/38G)** — investigate consumers before deploying
  anything new; do not delete Docker data without a recovery plan.
- Containers (all Coolify-managed unless noted):
  - `coolify`, `coolify-db`, `coolify-redis`, `coolify-realtime`, `coolify-proxy`,
    `coolify-sentinel`
  - Monitoring: `grafana`, `victoriametrics`, `vmauth`
  - Agents/apps: `openclaw`, `hermes-agent` (Coolify app, project "personal-agents",
    image `nousresearch/hermes-agent:v2026.5.7`), `agentmail`
- RAM headroom: ~1.9 GiB available of 3.7 GiB. Do not add memory-hungry services
  here; keep this box out of OOM territory. Do not run Chromium/crawling or a
  second always-on Hermes here.

## Vercel — web/presentation/deployment layer

- Account/team: `rajeev-6969` / "rajeev-6969's projects"
- `rajeevg.com` → project **`rajeevg-com`** (`prj_AVmeZk7nKjaypLsGHmjTIz1kmHby`,
  Next.js, Node 24.x). Production comes from the project's normal Git workflow.
- Do not create duplicate Vercel projects for existing sites; do not move
  workloads to Vercel unless their project architecture already fits.

## Networking / security

- Tailscale is the management network for Mac, Android phone, Oracle, Hetzner.
- Hermes dashboard binds only to Oracle's Tailscale IP (`100.112.158.79:9119`)
  and sits behind basic auth. It is not reachable from the public internet.
- Coolify admin lives behind `coolify-proxy`; API is used over HTTPS with a
  scoped token. No new public admin ports were opened.
- Oracle → Hetzner SSH runs over Tailscale with a dedicated key (`oracle-hermes`).
- Secrets live in `~/.secrets/` (Oracle, 0600) or the macOS Keychain. Never
  commit secrets; document locations and renewal, not values.

## Resource check commands

```bash
# from any host (via Tailscale aliases):
ssh oracle 'free -h; df -h /; nproc; uptime; sudo docker ps'
ssh jeev-hetz-1 'free -h; df -h /; nproc; uptime; docker ps; docker stats --no-stream'
# Hermes can answer the same questions in chat, e.g. "What is using RAM on Oracle?"
```

## Worker-concurrency guardrails (Oracle)

- Start: **1–2 concurrent browser workers**, 1 batch job queue, no local LLM.
- Watch `uptime` load (alert > 1.5 for sustained) and `free -h` available
  (< 1 GiB = stop queue) before increasing concurrency.
- Prefer cron/queued jobs over always-on containers on Oracle; stop what you
  are not using (Oracle bills as always-free but CPU steal is real).