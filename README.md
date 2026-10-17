# infra: Dotfiles, Dev Environments & Homelab as Code

Two parts in one repo:

- **Dev environment / dotfiles** for **Arch Linux**, **WSL**, **Fedora** and **Ubuntu / Debian** (one-command bootstrap below).
- **Homelab as code**: Proxmox VMs/LXCs with **Terraform**, configuration and Docker stacks with **Ansible**, secrets with **SOPS + age**. See [docs/homelab/README.md](docs/homelab/README.md).

---

## ⚡ Instant Setup (One-Command)

Run this single command in a terminal on **any fresh system** (Arch, WSL, Fedora VM, or Ubuntu):

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/uarslandev/infra/main/bin/dotfiles)"
```

### What this command does automatically:
1. **Detects the OS & Environment**: Identifies Arch Linux, WSL, Fedora, or Ubuntu/Debian.
2. **Bootstraps Prerequisites**: Automatically installs `ansible`, `git`, and `python3` via the native package manager (`pacman`, `dnf`, or `apt`).
3. **Clones Repository**: Clones this configuration repository to `~/.dotfiles`.
4. **Installs Galaxy Requirements**: Pulls required Ansible collections (`community.general`).
5. **Asks for your sudo password once** (only if sudo needs one) and passes it to both playbooks, so no package install is silently skipped.
6. **Applies Dotfiles & Tools**: Executes [`main.yml`](main.yml) on localhost to install base packages, then clones [`uarslandev/dotfiles`](https://github.com/uarslandev/dotfiles) to `~/Repos/dotfiles` and runs its playbook (zsh, neovim, tmux, docker, kubectl, helm, k9s, terraform, fonts, ...).
7. **Exposes the `dotfiles` CLI**: Symlinks `dotfiles` to `~/.local/bin/dotfiles` so you can update and re-sync your environment anytime by simply running `dotfiles`.

---

## 📦 Alternative: Clone & Run

If you prefer to clone the repository manually before running:

```bash
# 1. Clone the repository
git clone https://github.com/uarslandev/infra.git ~/.dotfiles
cd ~/.dotfiles

# 2. Run the bootstrap runner
./bin/dotfiles
```

---

## 💻 Supported Environments

| Environment | Supported Features | Package Manager | Desktop Services |
| :--- | :--- | :--- | :--- |
| **Arch Linux** (Bare-metal) | Pacman + Paru (AUR), Sway/Plasma, Ly DM, `pkgSync` | `pacman` + `paru` | Enabled |
| **WSL** (Windows Subsystem) | Fast CLI stack, Zsh, Neovim, Tmux, DevOps tools, Dotfiles | Native (`apt`/`dnf`/`pacman`) | Auto-skipped |
| **Fedora VM** / Host | Modern CLI dev stack, Starship, Fastfetch, Dotfiles | `dnf` | Tailored |
| **Ubuntu / Debian** | Build-essential, CLI dev stack, Starship, Dotfiles | `apt` | Tailored |

---

## 🏗️ Repository Structure

```
.
├── bin/
│   ├── dotfiles                 # Universal bootstrap CLI (supports curl | bash and local runs)
│   └── bootstrap -> dotfiles    # Symlink alias for bootstrapping
├── pre_tasks/                   # Multi-OS detection & normalization
│   ├── normalize_distribution.yml # Normalizes CachyOS/EndeavourOS -> Archlinux, Debian -> Ubuntu
│   ├── detect_wsl.yml           # Identifies WSL environment
│   ├── detect_session.yml       # Identifies desktop vs wsl vs headless/server session
│   ├── detect_sudo.yml          # Non-blocking privilege and package manager detection
│   ├── whoami.yml               # Resolves target non-root user and home directory
│   └── whoami_wsl.yml           # Resolves Windows host user in WSL
├── requirements/
│   ├── common.yml               # Galaxy collections for the dev env (community.general)
│   └── homelab.yml              # Pinned collections for homelab.yml
├── main.yml                     # Universal entrypoint (runs pre_tasks + dynamic roles on localhost)
├── ansible.cfg                  # Non-blocking configuration (become_ask_pass = False)
├── inventory.ini                # Dev inventory (localhost, workstations, wsl, vms)
├── group_vars/
│   ├── all.yml                  # Global pipeline, role exclude filters, and Ubuntu/Fedora packages
│   └── workstations.yml         # Arch Linux package definitions (pkgSync compatible)
├── host_vars/
│   ├── pc.yml                   # Machine-specific packages (e.g. NVIDIA drivers)
│   └── thinkpad.yml             # Machine-specific packages (e.g. ZFS tools)
├── scripts/
│   ├── pkgSync                  # Arch Linux package synchronization utility
│   └── tmux-sessionizer         # Tmux session manager script
└── roles/
    ├── common/                  # Scaffolds ~/.local/bin, ~/.config, ~/.local/share
    ├── workstation/
    │   ├── tasks/main.yml       # Dispatches to distro tasks; guards desktop services
    │   ├── tasks/Archlinux.yml  # Pacman + paru + pkgSync (with WSL/VM hardware filtering)
    │   ├── tasks/Ubuntu.yml     # Apt packages + starship installer
    │   └── tasks/Fedora.yml     # Dnf packages (starship, fastfetch)
    ├── devops_tools/            # Docker group & devops CLI tools (Arch/Fedora; on Ubuntu the dotfiles repo does this)
    └── dotfiles/                # Clones uarslandev/dotfiles and runs its playbook
```

Homelab (only run explicitly, never by the bootstrap):

```
├── homelab.yml                  # Proxmox host, apps VM (Docker + stacks), AdGuard, WireGuard
├── inventories/homelab/         # Homelab inventory + group_vars
├── roles/                       # ssh_access, proxmox_host, zfs_datasets, sanoid, node_exporter, docker_host, stacks, adguard, wireguard
├── stacks/<service>/compose.yml # Docker Compose stacks with pinned image versions
├── terraform/proxmox/           # bpg/proxmox: Ubuntu cloud image, apps VM, LXCs, virtiofs shares
├── secrets/*.sops.yml           # SOPS + age encrypted secrets (key never in git)
└── docs/homelab/                # Architecture, inventory, rebuild-from-zero runbook
```

---

## 📂 Managing Dotfiles

Dotfiles live in [`uarslandev/dotfiles`](https://github.com/uarslandev/dotfiles), a separate Ansible project
(one role per tool). The `dotfiles` role here clones it to `~/Repos/dotfiles` and runs its `main.yml`. Roles
without tasks for the current distribution (e.g. `plasma` on Ubuntu, macOS-only roles) skip themselves.

- Run everything: `dotfiles` (or `make apply`). Only the dotfiles part: `make dotfiles`.
- Progress of the nested run: `tail -f ~/.cache/dotfiles-last-run.log`.
- Change a dotfile: edit it in `~/Repos/dotfiles`, commit and push there. The next `dotfiles` run on any machine
  pulls it. With uncommitted local changes the pull is skipped and the checked-out version is applied.

---

## 🎯 Selective Execution (Tags)

Run only specific parts of your configuration anytime:

```bash
# Sync dotfiles only:
dotfiles --tags dotfiles
# Or: ansible-playbook main.yml --tags dotfiles

# Run only DevOps tools setup:
dotfiles --tags devops
# Or: ansible-playbook main.yml --tags devops

# Run only base workstation packages:
dotfiles --tags workstation
# Or: ansible-playbook main.yml --tags workstation

# Run only directory scaffolding:
dotfiles --tags common
# Or: ansible-playbook main.yml --tags common
```

---

## 📦 Arch Linux Package Synchronization (`pkgSync`)

On Arch Linux workstations, two-way package synchronization between your installed system packages and Ansible is handled via `pkgSync`:

```bash
# Check package drift between system and workstations.yml:
pkgSync

# Update group_vars/workstations.yml to match installed system packages:
pkgSync --apply

# Interactively review package changes:
pkgSync --interactive

# Add or remove packages:
pkgSync --add spotify
pkgSync --remove foot
```
