# infra: Homelab as Code

Proxmox VMs/LXCs with **Terraform**, configuration and Docker stacks with **Ansible**, secrets with **SOPS + age**.
Start with [docs/homelab/README.md](docs/homelab/README.md) (architecture, runbooks) and
[docs/homelab/OVERVIEW.md](docs/homelab/OVERVIEW.md) (how it works).

> **Looking for the dev environment / dotfiles?** It moved to
> [uarslandev/dotfiles](https://github.com/uarslandev/dotfiles):
>
> ```bash
> bash -c "$(curl -fsSL https://raw.githubusercontent.com/uarslandev/dotfiles/main/bin/dotfiles)"
> ```
>
> The old command (`.../uarslandev/infra/main/bin/dotfiles`) still works and forwards there.

## Usage

`make help` lists everything. The main flow:

```
make tf-plan    → make tf-apply       Terraform: VM + LXCs on Proxmox
make homelab-check → make homelab     Ansible: SSH keys, ZFS, Docker + stacks, AdGuard, WireGuard
make cf-plan    → make cf-apply       Terraform: public routes via Cloudflare Tunnel
make homelab-lint                     Before every commit
```

## Repository structure

```
├── homelab.yml                  # Proxmox host, apps VM (Docker + stacks), AdGuard, WireGuard
├── ansible.cfg                  # No default inventory: always -i inventories/homelab (the Makefile does)
├── inventories/homelab/         # Homelab inventory + group_vars
├── roles/                       # common, ssh_access, proxmox_host, zfs_datasets, sanoid, node_exporter,
│                                # docker_host, stacks, adguard, wireguard
├── stacks/<service>/compose.yml # Docker Compose stacks with pinned image versions
├── terraform/proxmox/           # bpg/proxmox: Ubuntu cloud image, apps VM, LXCs, virtiofs shares
├── terraform/cloudflare/        # Cloudflare Tunnel routes + DNS
├── secrets/*.sops.yml           # SOPS + age encrypted secrets (key never in git)
├── scripts/homelab/             # Helpers behind the make targets
├── requirements/homelab.yml     # Pinned Ansible collections
├── bin/dotfiles                 # Forwarder to the dotfiles repo (keeps the old bootstrap URL working)
└── docs/homelab/                # Architecture, inventory, rebuild-from-zero runbook
```
