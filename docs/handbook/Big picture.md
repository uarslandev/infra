---
tags: [infra, homelab]
---
# Big picture

Back to [[Home]].

## One server, four layers

```
┌───────────────────────────────────────────────────────────────┐
│ 3. APPS      Docker Compose stacks (stacks/)        ← Ansible  │
│ 2. SYSTEMS   packages, SSH, Docker, DNS, VPN        ← Ansible  │
│ 1. MACHINES  VM, LXCs, disks, shares                ← Terraform│
│ 0. DATA      ZFS pool "tank" (2 × 2 TB mirror)      ← snapshots│
└───────────────────────────────────────────────────────────────┘
   Secrets for every layer: SOPS + age, encrypted in git (secrets/)
```

- **Machines are disposable, data is not.** The apps VM keeps nothing of its own: every app's data
  lives on the ZFS pool `tank` and is passed into the VM. Terraform can recreate the VM in about a
  minute, and Ansible sets it up again. See [[Proxmox and ZFS]].
- **The repo is the single source of truth.** Nothing is changed on a server by hand. Change the repo,
  deploy, commit. A change made by hand is overwritten by the next run.

## What runs where

```
Your PC (WSL, ~/.infra)  ── git push ──►  GitHub uarslandev/infra  ◄── Renovate (update PRs)
   │ make … (Terraform, Ansible)              └─ CI: lint, validate, secrets encrypted
   ▼
Proxmox host (one physical server)
├── ZFS pool tank: immich · nextcloud · jellyfin · syncthing · appdata · apex · legacy
├── VM  110 "apps"       Ubuntu 26.04 + Docker: every app (Traefik, Immich, Nextcloud, Jellyfin,
│                        Syncthing, monitoring, APEX, cloudflared)
├── LXC 120 "adguard"    LAN DNS: *.home.<domain> → apps VM
└── LXC 121 "wireguard"  VPN for reaching all of this from outside
```

- **VM** = a full virtual machine with its own kernel (Docker needs that).
- **LXC** = a light Linux container sharing the host's kernel; enough for small services.

## Who can reach what

| From | Reaches | How |
| --- | --- | --- |
| Your home network | every app at `https://<name>.home.<domain>` | AdGuard DNS + Traefik, see [[Networking]] |
| Outside, as you | the same | WireGuard VPN first, see [[Networking]] |
| The internet | only the APEX API and the APEX website | Cloudflare Tunnel, see [[Cloudflare]] |

Admin UIs (Proxmox, AdGuard, Grafana, Traefik, the APEX admin) are **never** public.

## The daily loop

1. Change something in the repo (on your PC).
2. Dry run: `make homelab-check` (and/or `make tf-plan`, `make cf-plan`).
3. Apply: `make homelab` / `--tags apps` / `make tf-apply` / `make cf-apply`.
4. Commit and push. CI checks it again.

Details per tool: [[Tools]]. Step by step: [[Runbooks]].
