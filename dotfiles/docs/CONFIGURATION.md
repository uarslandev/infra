# Configuration Reference

## Quick Start

```bash
cp group_vars/all.yml.example group_vars/all.yml
nvim group_vars/all.yml
```

## What's Configurable via Ansible

These are the things you configure in `group_vars/all.yml`:

### Identity

| Variable | Required | Description |
|----------|----------|-------------|
| `git_user_name` | Yes | Your name for git commits |
| `op_account` | No | 1Password CLI account, default `my.1password.com` |
| `op.git.user.email` | Yes | 1Password path to your email |

```yaml
git_user_name: "Your Name"

op_account: my.1password.com

op:
  git:
    user:
      email: "op://Personal/GitHub/email"
```

### Role Selection

| Variable | Description |
|----------|-------------|
| `default_roles` | Role list used by `dotfiles` / `--tags all` |
| `exclude_roles` | Roles dropped from default runs |
| `exclude_roles_by_distribution` | Per-distribution roles pruned from default runs only |

```yaml
default_roles:
  - system
  - git
  - neovim
  - tmux
exclude_roles:
  - docker
```

Explicit tags still run even when a role is excluded, for example
`dotfiles -t docker`. Each role only runs the task file for the current
distribution (`Archlinux.yml`, `Ubuntu.yml`, `Fedora.yml`); a role without a
task file for your distro is skipped silently.

### Arch/CachyOS Package Source Policy

Arch-family roles use native package sources in this order:

1. `pacman` official repositories first.
2. AUR (via `kewlfft.aur`) only when the package is absent from official
   repositories, for example `1password` and the `neovim-git` nightly.

CachyOS is normalized to `Archlinux` before role dispatch, so Arch task files
cover both vanilla Arch and CachyOS.

Pacman module calls also inherit these defaults from `group_vars/all.yml`:

```yaml
arch_pacman_extra_args: "--disable-download-timeout"
arch_pacman_update_cache_extra_args: "--disable-download-timeout"
arch_pacman_upgrade_extra_args: "--disable-download-timeout"
```

That avoids false failures from CachyOS mirror stalls on large packages while
still letting pacman verify signatures and package integrity.

### Keyboard

These variables are consumed by Linux system/X11 keyboard setup (`localectl`
on Arch/Fedora). They are unused on WSL.

| Variable | Description |
|----------|-------------|
| `keyboard.model` | XKB keyboard model for Linux console/X11 paths |
| `keyboard.layout` | XKB layout, for example `us` |
| `keyboard.variant` | XKB variant, for example `dvorak` |
| `keyboard.options` | XKB options list, for example `caps:none` |

```yaml
keyboard:
  model: pc105
  layout: us
  options:
    - caps:none
```

### Package Lists

| Variable | Description |
|----------|-------------|
| `go.packages` | Go packages to install via `go install` |
| `npm_global_packages` | NPM packages (in `roles/npm/defaults/main.yml`) |

```yaml
go:
  packages:
    - package: github.com/go-task/task/v3/cmd/task@latest
      cmd: task
```

### Versions

| Variable | Default | Description |
|----------|---------|-------------|
| `nvm_node_version` | `"lts/*"` | Node.js version via NVM |

## What's NOT Configurable via Ansible

Everything else is configured by editing the actual config files directly:

| Tool | Config Location |
|------|-----------------|
| tmux | `roles/tmux/files/tmux/tmux.conf` |
| neovim | `roles/neovim/files/` |
| bash | `roles/bash/files/.bashrc` |
| git | `roles/git/files/gitconfig` |
| btop | `roles/btop/files/btop.conf` |

This is intentional. Config files are readable, portable, and self-contained.
You look at the file and know exactly what it does.

## Commands

```bash
dotfiles                    # Run all default roles
dotfiles -t neovim,git      # Run specific roles
dotfiles --check            # Dry run
dotfiles -e "var=value"     # Override variable
```
