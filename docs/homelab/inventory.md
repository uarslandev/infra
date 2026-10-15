# Homelab inventory

Current state after the rebuild on 2026-10-15. IPs, hostnames, MACs and domains are intentionally left out (public repo).
What existed before the rebuild is summarised under "Removed in the rebuild" below.

## Host

| Item | Value |
| --- | --- |
| Proxmox VE | 9.2.4 |
| CPU / RAM | 12 threads (Xeon E5-2620 v2), 62 GB |
| Boot disk | 120 GB SATA SSD, OS only (~17 % used); ~116,800 power-on hours: plan a replacement |
| Data pool `tank` | mirror 2 × 2 TB HDD, ONLINE; one disk has 2 reallocated sectors (watch SMART) |

## Guests (all managed by Terraform, disks on `tank`)

| ID | Type | Name | OS | Purpose |
| --- | --- | --- | --- | --- |
| 110 | VM | apps | Ubuntu 26.04 | Docker host for all stacks (8 cores, 24 GB) |
| 120 | LXC | adguard | Ubuntu 26.04 | LAN DNS (AdGuard Home v0.107.78) |
| 121 | LXC | wireguard | Ubuntu 26.04 | WireGuard VPN (5 peers, config restored unchanged) |

## Stacks on `apps`

| Stack | Version | Data |
| --- | --- | --- |
| immich | v3.1.0, Postgres 14 + vectorchord 0.4.3 | `tank/immich` (17,013 assets, 165 GB) |
| nextcloud | 34.0.2, MariaDB 12.3.2, Redis 8.10.0, cron container | `tank/nextcloud` (109 GB) |
| jellyfin | 10.11.11 (CPU transcoding) | `tank/jellyfin` |
| syncthing | 2.1.3 | `tank/syncthing` |
| teamspeak | 3.13.7 | `tank/appdata/teamspeak` |
| npm | 2.15.1 | `tank/appdata/npm` |
| uptime-kuma | 2.5.6 | `tank/appdata/uptime-kuma` |
| cloudflared | 2026.8.3 | none (token in SOPS) |

## Removed in the rebuild

servarr (Fedora VM), pterodactyl VM, nas-share, nginxproxymanager, the old adguard and wireguard LXCs (Debian),
Dockge, Forge, GPU passthrough (Quadro K420 too old for current drivers), 7,279 legacy snapshots.
Unused datasets kept for now: `tank/firefly_iii`, `tank/forge`; `/tank/docker-backup` and `/tank/dockge` in the pool root.
