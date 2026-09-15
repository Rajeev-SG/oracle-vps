# Access & integrations (Hermes on Oracle → Hetzner / Coolify / GitHub / Vercel)

Credential values are never committed. This file records **locations and renewal**.

## Oracle → Hetzner (SSH over Tailscale)

- Dedicated keypair `~/.ssh/hetzner` (comment `oracle-hermes`), public key added
  to Hetzner `root@jeev-hetz-1` `authorized_keys`. Password SSH stays disabled.
- Alias (Oracle `~/.ssh/config`): `Host jeev-hetz-1` → `100.109.237.19`.
- Traffic rides the tailnet; no new public admin ports.
- Verify: `ssh oracle 'ssh jeev-hetz-1 hostname'` → `jeev-hetz-1`
- Key rotation: generate a new key on Oracle, append the pub key on Hetzner,
  remove the old line, replace `~/.ssh/hetzner`.

## Coolify

- Dashboard: https://coolify.rajeevg.com (admin UI, root team)
- API token (read + write + deploy, no expiry): Oracle `~/.secrets/coolify-api-token`,
  0600, directory 0700. Usage:
  ```bash
  curl -H "Authorization: Bearer $(cat ~/.secrets/coolify-api-token)" \
       https://coolify.rajeevg.com/api/v1/applications
  ```
- Renewal: create a new token in Coolify → Keys & Tokens → API Tokens (read,
  write, deploy), replace the file. Revoke the old one.
- Escape hatch: `ssh jeev-hetz-1` for host-level diagnostics Coolify cannot give.
  Do not hand-edit Coolify-managed containers unless the API cannot do it.

## GitHub

- `gh` on Oracle authenticated as **Rajeev-SG** (`~/.config/gh/hosts.yml`, 0600)
  with `repo`, `workflow`, `read:org` scopes — token reused from the Mac keychain.
- Renewal: on the Mac `gh auth token`, then on Oracle
  `gh auth login --with-token`. Rotation via GitHub → Settings → Developer
  settings (or `gh auth refresh` on the Mac).

## Vercel

- CLI 59.x installed via npm (Hermes-managed Node 26) on Oracle.
- Auth: `~/.local/share/com.vercel.cli/auth.json` (0600), account `rajeev-6969`,
  team "rajeev-6969's projects". Verify: `vercel whoami`.
- Project: **`rajeevg-com`** linked at `~/rajeevg.com/.vercel/project.json`
  (`prj_AVmeZk7nKjaypLsGHmjTIz1kmHby`). The same project ID backs production —
  no duplicate project exists.
- Preview from Oracle (always pass an explicit target — CLI 59 deploys from the
  default branch as target=production otherwise, which will not touch
  rajeevg.com's aliasing but still creates a production-target deployment):
  ```bash
  cd ~/rajeevg.com && gh repo pull && vercel deploy --target preview --yes
  ```
- Production: `vercel deploy --prod` **only when explicitly requested**.
  Normal production flow stays the repo's Git integration.
- Renewal: create a new token on the Mac (`vercel login` there) or at
  vercel.com/account/tokens and replace `auth.json` (`token` field).

## Secrets inventory (locations only)

| Secret | Location | Notes |
|---|---|---|
| OpenRouter key | Oracle `~/.hermes/.env` | 0600; also macOS Keychain `codex-openrouter` |
| Coolify API token | Oracle `~/.secrets/coolify-api-token` | read+write+deploy |
| Dashboard password | Oracle `~/.secrets/dashboard-password` | hash in `~/.hermes/.env` |
| Hetzner SSH key | Oracle `~/.ssh/hetzner` | dedicated, comment `oracle-hermes` |
| GitHub token | Oracle `~/.config/gh/hosts.yml` | via keychain on Mac |
| Vercel auth | Oracle `~/.local/share/com.vercel.cli/auth.json` | headless token |

Hetzner root password (Hetzner web console recovery only) stays in
`~/Projects/Hetzner/HETZNER_SECRETS.txt` on the Mac — never on Oracle, never in git.