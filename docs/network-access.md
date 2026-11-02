# Network access and recovery

Network hardening applied 2026-11-02. Exact source allowlists, device policy and
firewall snapshots are kept in the private
[codex-home network security baseline](https://github.com/Rajeev-SG/codex-home/blob/main/docs/network-security.md)
(GitHub access required). They are deliberately not duplicated in this public repo.

## Normal access

- Use Tailscale for management away from the admin home network. Public SSH is
  key-only and source-restricted; a timeout away from home is expected.
- On the Mac, `ssh oracle-ts` reaches Oracle over Tailscale. The existing
  `ssh oracle` and `ssh jeev-hetz-1` aliases use public IPs and remain usable from
  the allowed home source. Use Hetzner's tailnet address away from home.
- Both registered Macs retain administrative access to the five enrolled devices.
  Android access is limited to SSH and the existing web/remote-coding/media
  services. New devices do not inherit the former all-to-all grant.
- Oracle may reach Hetzner on SSH ports `22` and `2222`; server-to-Mac access and
  Hetzner-to-Oracle dashboard access are denied by the Tailscale policy.
- Hermes dashboard remains at `http://100.112.158.79:9119`, authenticated and
  Tailscale-only; phone access remains permitted.

## Coolify

Use `https://coolify.rajeevg.com` for the UI/API. Direct public TCP ports `8000`,
`6001`, `6002` and `8080` are blocked over both IPv4 and IPv6. Existing HTTPS
proxy routes carry realtime and terminal traffic, so do not reopen those ports
to fix a direct-port connection failure.

The controls are persistent host UFW/`DOCKER-USER` rules, not an attached Hetzner
cloud firewall. Docker-published ports need forwarding-chain protection; UFW's
ordinary incoming-service rules alone are not sufficient.

## Unattended database tunnel

Oracle's `adi-db-tunnel.service` uses dedicated real sshd port `2222` on Hetzner's
Tailscale interface and the restricted `adi-worker` key. It forwards Oracle
loopback port `55432` to Hetzner's loopback database port `55432`. Keep this route:
port `22` uses Tailscale SSH check mode and can require interactive authentication.
No PostgreSQL port is public.

## Recovery

1. Keep a verified tailnet SSH session or provider console available before
   changing public source allowlists. Do not turn off Tailscale first.
2. If the home public IP changes, inspect the live OCI security list and Hetzner
   UFW rules, add the replacement narrow source rule, verify a new SSH session,
   then remove the obsolete source. Do not open SSH to the whole internet.
3. Before a firewall restore/reload, compare with the private snapshots and retain
   newer host rules. Do not overwrite live UFW files or replace OCI's full ingress
   list without preserving the existing Tailscale/ICMP allowances and egress.
4. After an authorized change, verify fresh SSH, Coolify HTTPS and
   `systemctl is-active adi-db-tunnel.service` on Oracle; check that the loopback
   database tunnel accepts a connection and unwanted public ports remain blocked.

The active tunnel, fresh admin SSH, HTTPS endpoints and representative denied
connections were verified after hardening. Phone and older Mac were offline;
interactive Coolify deployment/terminal and reboot behaviour were not live-tested.
