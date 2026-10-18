# infra: Dev Environment, Dotfiles & Homelab as Code

One repo for all my infrastructure:

- **Dev environment / dotfiles** ([`dotfiles/`](dotfiles/README.md)): Ansible project that installs every tool and
  its config on **Arch/CachyOS**, **Ubuntu** (desktop, WSL, server) and **Fedora**. One role per tool, the config
  files next to it (e.g. `dotfiles/roles/neovim/files/`).
- **Homelab as code**: Proxmox VMs/LXCs with **Terraform**, configuration and Docker stacks with **Ansible**, secrets
  with **SOPS + age**. See [docs/homelab/README.md](docs/homelab/README.md) and
  [docs/homelab/OVERVIEW.md](docs/homelab/OVERVIEW.md).

## Set up a machine

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/uarslandev/infra/main/bin/dotfiles)"
```

Clones this repo to `~/.infra`, links `~/.dotfiles` → `~/.infra/dotfiles` (the shell config expects
`~/.dotfiles`), asks for the sudo password once and runs the dev environment playbook. Afterwards: `dotfiles`
(or `make dotfiles`) applies changes, `dotsave "msg"` / `wip "msg"` commits and pushes this repo.

## Homelab

`make help` lists everything. The main flow:

```
make tf-plan       → make tf-apply      Terraform: VM + LXCs on Proxmox
make homelab-check → make homelab       Ansible: SSH keys, ZFS, Docker + stacks, AdGuard, WireGuard
make cf-plan       → make cf-apply      Terraform: public routes via Cloudflare Tunnel
make homelab-lint                       Before every homelab commit
```

## Repository structure

```
├── bin/dotfiles                 # Bootstrap for any machine (clone, link ~/.dotfiles, run dotfiles/)
├── dotfiles/                    # Dev environment: own Ansible project (main.yml, roles/, group_vars/, ansible.cfg)
│   ├── roles/<tool>/            # Install tasks per distro + the tool's config files
│   ├── roles/packages/          # Base packages per distro, Arch pacman/AUR lists (pkgSync)
│   └── archinstall.sh           # Arch installer (the ISO is built by .github/workflows/build_arch_iso.yml)
├── homelab.yml                  # Proxmox host, apps VM (Docker + stacks), AdGuard, WireGuard
├── ansible.cfg                  # Homelab; no default inventory: always -i inventories/homelab (the Makefile does)
├── inventories/homelab/         # Homelab inventory + group_vars
├── roles/                       # Homelab roles: common, ssh_access, proxmox_host, zfs_datasets, sanoid,
│                                # node_exporter, docker_host, stacks, adguard, wireguard
├── stacks/<service>/compose.yml # Docker Compose stacks with pinned image versions
├── terraform/proxmox/           # bpg/proxmox: Ubuntu cloud image, apps VM, LXCs, virtiofs shares
├── terraform/cloudflare/        # Cloudflare Tunnel routes + DNS
├── secrets/*.sops.yml           # SOPS + age encrypted secrets (key never in git)
├── scripts/homelab/             # Helpers behind the make targets
├── requirements/homelab.yml     # Pinned Ansible collections (homelab)
└── docs/homelab/                # Architecture, inventory, rebuild-from-zero runbook
```

The dev environment and the homelab are separate Ansible projects (own `ansible.cfg`, roles and inventories), so
role names like `wireguard` exist in both without clashing. Its history came along from the former
`uarslandev/dotfiles` repo (`git log dotfiles/...` works).
