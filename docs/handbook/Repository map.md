---
tags: [infra, reference]
---
# Repository map

Back to [[Home]]. Every folder and file at the top of the repo, and which note explains it.

```
infra/
├── Makefile                  short names for the long commands → [[Tools#Make]]
├── ansible.cfg               Ansible settings for the homelab (no default inventory, on purpose)
├── homelab.yml               the homelab playbook: which roles run on which machines → [[Tools#Ansible]]
├── inventories/homelab/
│   ├── hosts.yml             the machines (Proxmox host, apps VM, the two LXCs) and their groups
│   └── group_vars/           settings per group:
│       ├── all.yml           timezone, SSH keys, domain names, admin networks
│       ├── proxmox.yml       ZFS datasets, snapshot policies → [[Proxmox and ZFS]]
│       ├── docker_hosts.yml  which stacks run, apex_version, probes, Traefik routes → [[Apps VM and stacks]]
│       └── adguard.yml       the LAN DNS names → [[Networking]]
├── roles/                    the homelab roles ("how"), one folder each:
│   ├── common                user dirs, zsh as shell
│   ├── ssh_access            authorized_keys + key-only sshd → [[Networking#SSH]]
│   ├── proxmox_host          host packages, kernel modules, SMART
│   ├── zfs_datasets          creates the datasets in tank
│   ├── sanoid                snapshot policies → [[Proxmox and ZFS#Snapshots]]
│   ├── node_exporter         host metrics → [[Monitoring and alerts]]
│   ├── docker_host           Docker, log rotation, virtiofs mounts
│   ├── stacks                deploys every stack → [[Apps VM and stacks#The stacks role]]
│   ├── adguard               AdGuard Home + DNS rewrites
│   └── wireguard             the VPN
├── stacks/<app>/compose.yml  one Docker Compose file per app, versions pinned
├── terraform/
│   ├── proxmox/              VM, LXCs, images, shares → [[Tools#Terraform]]
│   └── cloudflare/           tunnel routes + DNS → [[Cloudflare]]
├── secrets/homelab.sops.yml  every homelab secret, encrypted → [[Secrets]]
├── .sops.yaml                which age public key encrypts what
├── scripts/homelab/          the helpers behind the make targets → [[Tools#The helper scripts]]
├── requirements/homelab.yml  pinned Ansible collections
├── renovate.json             automatic update PRs → [[CI, Renovate and agents]]
├── .github/workflows/        CI: lint.yml (homelab), dotfiles.yml, build_arch_iso.yml
├── .claude/agents/           AI review agents → [[CI, Renovate and agents#Agents]]
├── CLAUDE.md                 rules for AI assistants working in this repo
├── bin/dotfiles              one-line bootstrap for a new PC → [[Dev environment (dotfiles)]]
├── dotfiles/                 the dev-environment project (its own Ansible project)
└── docs/
    ├── handbook/             these notes
    └── homelab/              overview, runbook, inventory, TODO, how-deploys-work
```

## On the server (not in git)

| Path | What | Written by |
| --- | --- | --- |
| `/opt/stacks/<app>/` on the apps VM | `compose.yml`, `.env` (secrets, root-only), extra config | the `stacks` role |
| `/srv/<dataset>` on the apps VM | the app data, a ZFS dataset passed in via virtiofs | `docker_host` (mount), Terraform (share) |
| `/tank/<dataset>` on the Proxmox host | the same data, where it really lives | `zfs_datasets` |

## On your PC (not in git)

| Path | What |
| --- | --- |
| `~/.config/sops/age/keys.txt` | the age private key: decrypts every secret. Also in KeePass + printed. |
| `terraform/*/terraform.tfstate` | Terraform's state; the encrypted copy is in git → [[Tools#Terraform state]] |
| `~/.ssh/` | your SSH key; `make ssh-config` adds the homelab hosts |
