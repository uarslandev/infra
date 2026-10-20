# Homelab TODO

Open work, most important first. Done items move to the bottom with a date.

## Next

- [ ] **Backups (highest priority)**: Proxmox Backup Server on the PVE host with a removable datastore on a USB disk
      (>= 1 TB); file-level backups of `tank/immich` + `tank/nextcloud` from a ZFS snapshot, PVE backups of VM/LXCs,
      verify + prune jobs, alert when the last backup is older than 36 h, real restore test.
      *Blocked on: buying the USB disk.* Until then the only copy is the pool itself.
- [ ] **APEX first admin + user account**: create the superuser via the SSH tunnel (README → "APEX sync server"), then
      the user account in the admin UI, and sign in from the app with `https://apex-api.<domain>`.
- [ ] **Renovate**: app installed on `infra` only; no Dependency Dashboard yet. Check developer.mend.io logs / trigger a scan.

## Later

- [ ] Other Cloudflare settings still in the dashboard (zone SSL/TLS, WAF, the tunnel itself): import into
      `terraform/cloudflare` if they ever change. The provider no longer manages the tunnel's `warp-routing` flag.
- [ ] Alert when a public admin path stops answering 404 (blackbox probe expecting 404 for `apex-api.<domain>/_/`).
- [ ] E-mail for apps (password reset, confirmations): free transactional provider (e.g. Brevo) via SMTP, not a self-hosted MTA.
- [ ] After backups are verified: delete `tank/legacy` and release the `keep` holds on `@pre-rebuild-20261015` (explicit OK).
- [ ] Offsite copy: once the new server exists, the old one becomes a PBS sync target at another location.
- [ ] Hardware: boot SSD has ~116,800 power-on hours; one HDD has 2 reallocated sectors (SMART alert is in place).
- [ ] New server: plan together (the repo already rebuilds everything except the data on `tank`).

## Done

- 2026-10-20: portfolio stack (uarslan.com) — static Astro site built on the VM from a pinned commit of the
  private `portfolio` repo (read-only deploy key), Caddy on 127.0.0.1:8092, tunnel route for the zone root +
  DNS in Terraform. Imported the pre-existing `apex_web` DNS record into Terraform state (drift fix).
- 2026-10-20: forge stack (forge.<domain>) — full-stack app (Postgres + Fastify + nginx/PWA) built on the VM
  from a pinned commit of the private `forge` repo; DB on a new `tank/forge` ZFS dataset (sanoid standard) via
  a new virtiofs share (apps VM updated in-place + rebooted); only the web service public, /api proxied
  internally; tunnel route + DNS in Terraform; secrets forge_deploy_key/postgres_password/jwt_secret in SOPS.
- 2026-10-15: rebuilt as code (Terraform VM/LXCs on Ubuntu 26.04, Ansible roles, SOPS secrets), Immich + Nextcloud migrated.
- 2026-10-15: monitoring (Prometheus, Alertmanager -> e-mail, Grafana), key-only SSH + recovery key, Renovate config.
- 2026-10-16: Traefik with Let's Encrypt wildcard for `*.home.<domain>`, AdGuard rewrites as code, NPM retired.
- 2026-10-16: Grafana no longer public; old tunnel routes (forge, ssh) removed; encrypted Terraform state copy in git.
- 2026-10-16: APEX sync server (PocketBase, built from the private repo with a read-only deploy key, data on `tank/apex`,
  rate limits); public only `^/api/` via the tunnel; tunnel routes + DNS in Terraform (`terraform/cloudflare`).
- 2026-10-16: cleanup: TeamSpeak, Forge, Firefly III, old Docker backup (40 GB log), Dockge leftovers, old ISOs/templates removed.
