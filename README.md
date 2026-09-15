# oracle-vps

Operations repo for Rajeev's infrastructure: Oracle Always Free VPS (worker/agent box),
Hetzner VPS (persistent services via Coolify), and Vercel (public web).

| Doc | Purpose |
|-----|---------|
| [docs/architecture.md](docs/architecture.md) | Host responsibilities, recorded resources, placement rules, guardrails |
| [docs/hermes-oracle.md](docs/hermes-oracle.md) | Hermes Agent on Oracle: install, phone access, recovery, updates |
| [docs/access-and-integrations.md](docs/access-and-integrations.md) | How Hermes (and you) reach Hetzner, Coolify, GitHub, Vercel; credential locations |

Placement rule: **persistent/core → Hetzner; disposable/compute-heavy/background → Oracle; public web frontend/serverless → Vercel.**

Issues #1–#3 in this repo track the original requirements.