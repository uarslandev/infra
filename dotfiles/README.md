# dotfiles

Ansible-based development environment for **Arch/CachyOS**, **Ubuntu** (WSL + server), and **Fedora**.

Roles are idempotent and per-distro: each role only runs the tasks that exist for
the current distribution, so the same playbook works everywhere.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [How It Works](#how-it-works)
- [Configuration](#configuration)
- [1Password Integration](#1password-integration)
- [Usage](#usage)
- [Adding a Role](#adding-a-role)

## Prerequisites

No manual prerequisites — the bootstrap script installs Ansible and everything
else it needs for your OS. A full system upgrade first is recommended:

```bash
# Arch/CachyOS
sudo pacman -Syu
# Ubuntu
sudo apt-get update && sudo apt-get upgrade -y
# Fedora
sudo dnf update -y
```

## Quick Start

**Want it fast?** From the repo root:

```bash
./bin/dotfiles
```

**What happens:**
1. **Prerequisites** - Installs Ansible and bootstrap dependencies for your OS
2. **Repo** - Uses the repo this script lives in (or clones `DOTFILES_REPO_URL`)
3. **Configure** - Reads `group_vars/all.yml` for role selection and secrets
4. **Apply** - Runs `ansible-playbook` with your selected roles

**Next steps:**
- Copy `group_vars/all.yml.example` to `group_vars/all.yml` if a local config does not exist yet
- Set your name in `git_user_name`
- Set up [1Password integration](#1password-integration) for secret-backed roles
- Run `./bin/dotfiles` anytime to apply your environment

## How It Works

Every role has a `tasks/main.yml` that looks for a distro-specific task file:

```yaml
- name: "{{ role_name }} | Checking for Distribution Config: {{ ansible_facts['distribution'] }}"
  ansible.builtin.stat:
    path: "{{ role_path }}/tasks/{{ ansible_facts['distribution'] }}.yml"
  register: distribution_config

- name: "{{ role_name }} | Run Tasks: {{ ansible_facts['distribution'] }}"
  ansible.builtin.include_tasks: "{{ ansible_facts['distribution'] }}.yml"
  when: distribution_config.stat.exists
```

If `roles/<role>/tasks/<distro>.yml` exists (e.g. `Archlinux.yml`), it runs.
Otherwise the role skips that distro safely. CachyOS is normalized to
`Archlinux` in `pre_tasks/normalize_distribution.yml`, and WSL is detected in
`pre_tasks/detect_wsl.yml` (WSL hosts skip systemd service management).

Supported distributions:
- Archlinux / CachyOS (pacman + AUR via `kewlfft.aur`)
- Ubuntu / Debian (apt)
- Fedora (dnf)

### Privilege escalation

`pre_tasks/detect_sudo.yml` detects sudo/doas and whether credentials are
cached. Package roles skip privileged installs when `can_install_packages` is
false instead of failing the whole play. Pre-cache sudo with `sudo -v` before
running, or pass `--ask-become-pass`, if you don't use passwordless sudo.

## Configuration

Machine-specific configuration lives in `group_vars/all.yml` and travels with
the repo. It contains only role selection and `op://` secret references —
never plaintext secrets. Start from the checked-in example if you want a
fresh config:

```bash
cp group_vars/all.yml.example group_vars/all.yml
nvim group_vars/all.yml
```

Key settings:
- `default_roles`: roles that run when you execute `dotfiles`
- `git_user_name`: name used by git and other developer tooling
- `keyboard`: Linux keyboard model/layout/options (localectl on Arch/Fedora)
- role-specific variables such as `go.packages`

## 1Password Integration

1Password backs all secrets. Nothing hard-fails when the CLI is missing or
locked — affected roles skip secret sync and tell you how to retry. The
default account is `my.1password.com` (`op_account`).

Secret references use the CLI format `op://VaultName/ItemName/Field`. Never
put plaintext secrets in this repo.

#### Git identity and SSH signing

```yaml
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/GitHub SSH/allowed_signers"
```

`op.git.allowed_signers` should point to a field whose value is one or more
lines in git's SSH allowed signers format:

```text
you@example.com namespaces="git" ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA...
```

#### SSH keys

The ssh role deploys every key listed under `op.ssh.github` groups:

```yaml
op:
  ssh:
    github:
      personal:
        - name: id_ed25519
          vault_path: "op://Personal/GitHub SSH"
```

Each vault item must expose `private_key` and `public_key` fields.

## Usage

```bash
./bin/dotfiles                    # Run default_roles
./bin/dotfiles -t tmux -vvv       # Run one role with Ansible verbosity
./bin/dotfiles --check            # Dry run
./bin/dotfiles --list-tags        # List available role tags
./bin/dotfiles --uninstall neovim # Run a role uninstall script, if present
./bin/dotfiles --delete old_role  # Uninstall, remove from all.yml, and delete the role directory
```

`--uninstall` and `--delete` prompt before making destructive changes.

## Adding a Role

1. `mkdir -p roles/<name>/tasks`
2. Add `tasks/main.yml` with the distro dispatch snippet above
3. Add `tasks/Archlinux.yml`, `tasks/Ubuntu.yml`, `tasks/Fedora.yml` as needed
   (guard package installs with `when: can_install_packages | default(false)`)
4. Add the role to `default_roles` in `group_vars/all.yml`

See `docs/example-role/` for a working template and `docs/` for more guides.
