---
tags: [infra, index]
---
# Infra handbook

How the `uarslandev/infra` repo works, written to be read in Obsidian. Open the **`docs/`** folder as a
vault (Obsidian → *Open folder as vault*), so these notes and the older homelab docs link to each other.

> [!info] Two projects in one repo
> 1. **Homelab as code**: a Proxmox server, its VMs and containers, the apps on them, public access,
>    secrets, monitoring. Most of this handbook.
> 2. **Dev environment ("dotfiles")**: installs every tool and its config on your PCs and WSL.
>    See [[Dev environment (dotfiles)]].
> They never share roles or settings.

## Start here
1. [[Big picture]]: what runs where, and the four layers.
2. [[Repository map]]: every folder, and what it is for.
3. [[Tools]]: Make, Ansible, Terraform, SOPS + age, in plain words.

## The homelab, piece by piece
- [[Proxmox and ZFS]]: the server, the data pool, snapshots, how data reaches the apps.
- [[Apps VM and stacks]]: Docker, the stacks role, every app.
- [[Networking]]: LAN names, Traefik and certificates, AdGuard, WireGuard, SSH.
- [[Cloudflare]]: public access through the tunnel, routes, DNS, tokens.
- [[Secrets]]: what is secret, where it lives, how it gets to the server.
- [[Monitoring and alerts]]: Prometheus, Grafana, Alertmanager.
- [[APEX on the homelab]]: the one app built from your own code.
- [[CI, Renovate and agents]]: what checks every push, who proposes updates.

## Doing things
- [[Runbooks]]: step-by-step for the common jobs (deploy, new app, new public route, new device,
  new machine, restore a file, rebuild from zero).
- [[Glossary]]: the words used here.

## Older docs (still current)
- [[homelab/OVERVIEW|Homelab overview]] · [[homelab/README|Homelab runbook]] ·
  [[homelab/how-deploys-work|How deploys work]] · [[homelab/inventory|Inventory]] · [[homelab/TODO|TODO]]

> [!warning] The repo is public
> Nothing secret goes into these notes either: no tokens, passwords, keys, public IPs or the domain.
> The domain is written as `<domain>`.
