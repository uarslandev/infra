---
tags: [infra, homelab, network]
---
# Networking

Back to [[Home]]. How names, certificates, the VPN and SSH fit together. Public access is its own
note: [[Cloudflare]].

## A request on the home network

```
Browser: https://photos.home.<domain>
   │ 1. DNS: AdGuard answers "*.home.<domain> → apps VM"
   ▼
apps VM :443  Traefik
   │ 2. TLS with the Let's Encrypt wildcard certificate for *.home.<domain>
   │ 3. picks the route by hostname (Docker label on the Immich container)
   ▼
immich_server container
```

## AdGuard (LXC 120)

- AdGuard Home, a pinned release installed by the `adguard` role.
- **DNS rewrites are code**: `inventories/homelab/group_vars/adguard.yml` is the exact list; anything
  else is removed on the next run. One wildcard sends `*.home.<domain>` to the apps VM; a few old
  `*.home` names stay for now (Traefik redirects them).
- The rest of AdGuard's settings stay editable in its web UI.
- The servers themselves use the router as DNS, so the homelab does not depend on AdGuard to boot.

## Traefik

- Runs in the `traefik` stack on ports 80/443 of the apps VM.
- **Certificate**: a Let's Encrypt wildcard for `*.home.<domain>`. Let's Encrypt checks you own the domain
  by a DNS record (DNS-01) that Traefik writes at Cloudflare with `cloudflare_dns_api_token`. So the LAN
  gets real, trusted HTTPS without being reachable from the internet. Stored in
  `tank/appdata/traefik/acme.json`.
- **Routes**:
  - Docker apps: labels in their `compose.yml`, e.g.
    ``traefik.http.routers.photos.rule: Host(`photos.${LOCAL_DOMAIN}`)``;
  - non-Docker targets (Proxmox, AdGuard): `traefik_external_routes` in `docker_hosts.yml`, rendered into
    `stacks/traefik/config/dynamic/homelab.yml.j2`.
- **`lan-only` middleware**: an IP allow-list of `homelab_admin_networks` (LAN + WireGuard). Every admin UI
  uses it, so even a mistake elsewhere does not expose it.
- Docker access only through a read-only **socket proxy**, never the raw Docker socket.

## WireGuard (LXC 121)

- The VPN for reaching everything from outside, as if at home. Peers (your devices) are in the secret
  `wireguard_wg0_conf` → [[Secrets]]; the role writes `/etc/wireguard/wg0.conf` and starts `wg0`.
- Its network is in `homelab_admin_networks`, so `lan-only` lets it through.
- Quirk: Ubuntu's AppArmor profile for `wg-quick` breaks inside an unprivileged LXC; the role disables
  just that profile there.
- New device: [[Runbooks#New device]].

## SSH

- Role `ssh_access` on every host: **key-only** (`PasswordAuthentication no`,
  `PermitRootLogin prohibit-password`).
- `authorized_keys` is managed **exclusively** from `ssh_access_authorized_keys` in
  `group_vars/all.yml`: one public key per device plus an **offline recovery key** (private half only in
  KeePass, with passphrase). The role refuses to run with an empty list, and on Proxmox it keeps the
  node's own key.
- `make ssh-config` writes host entries from the inventory: `ssh proxmox`, `ssh apps`, `ssh adguard`,
  `ssh wireguard` work from WSL and Windows.
- SSH tunnel to a service that listens only on the VM itself, e.g. the APEX admin:
  `ssh -L 8090:127.0.0.1:8090 apps`, then `http://127.0.0.1:8090/_/`.

> [!warning] Changing SSH settings
> Keep a second session open while testing (never remove the last key or the Proxmox node key).
