# Homelab TODO

Open work, most important first. Done items move to the bottom with a date.

## Next

- [ ] **Backups (highest priority)**: Proxmox Backup Server on the PVE host with a removable datastore on a USB disk
      (>= 1 TB); file-level backups of `tank/immich` + `tank/nextcloud` from a ZFS snapshot, PVE backups of VM/LXCs,
      verify + prune jobs, alert when the last backup is older than 36 h, real restore test.
      *Blocked on: buying the USB disk.* Until then the only copy is the pool itself.
- [ ] **APEX sync server** as a stack: PocketBase from the private repo (`server/`), data on `tank/apex`,
      `127.0.0.1:8090`, public only `^/api/` via the tunnel (route in Terraform), admin UI via SSH tunnel, rate limits.
- [ ] **Renovate**: app installed on `infra` only; no Dependency Dashboard yet. Check developer.mend.io logs / trigger a scan.

## Later

- [ ] Cloudflare tunnel routes + DNS in Terraform (cloudflare provider) instead of the dashboard; first needed for APEX.
- [ ] E-mail for apps (password reset, confirmations): free transactional provider (e.g. Brevo) via SMTP, not a self-hosted MTA.
- [ ] After backups are verified: delete `tank/legacy` and release the `keep` holds on `@pre-rebuild-20261015` (explicit OK).
- [ ] Offsite copy: once the new server exists, the old one becomes a PBS sync target at another location.
- [ ] Hardware: boot SSD has ~116,800 power-on hours; one HDD has 2 reallocated sectors (SMART alert is in place).
- [ ] New server: plan together (the repo already rebuilds everything except the data on `tank`).

## Done

- 2026-10-15: rebuilt as code (Terraform VM/LXCs on Ubuntu 26.04, Ansible roles, SOPS secrets), Immich + Nextcloud migrated.
- 2026-10-15: monitoring (Prometheus, Alertmanager -> e-mail, Grafana), key-only SSH + recovery key, Renovate config.
- 2026-10-16: Traefik with Let's Encrypt wildcard for `*.home.<domain>`, AdGuard rewrites as code, NPM retired.
- 2026-10-16: Grafana no longer public; old tunnel routes (forge, ssh) removed; encrypted Terraform state copy in git.
- 2026-10-16: cleanup: TeamSpeak, Forge, Firefly III, old Docker backup (40 GB log), Dockge leftovers, old ISOs/templates removed.
