# Quick Start Guide

## What are dotfiles?

An Ansible playbook that installs and configures your whole dev environment —
tools, shells, and configs — idempotently across **Arch/CachyOS**, **Ubuntu**
(WSL + server), and **Fedora**.

## Step 1: Update Your System

```bash
# Arch Linux / CachyOS
sudo pacman -Syu
# Ubuntu
sudo apt-get update && sudo apt-get upgrade -y
# Fedora
sudo dnf update -y
```

## Step 2: Run the Bootstrap

From the repo root:

```bash
./bin/dotfiles
```

**What you'll see:**
1. Detected OS and its bootstrap packages installed (Ansible, python, git)
2. Ansible galaxy collections installed
3. `ansible-playbook` running your selected roles

**If something goes wrong:**
The bootstrap shows the failing command's output. Most issues are missing sudo
credentials — run `sudo -v` first, or rerun with `--ask-become-pass`.

## Step 3: Basic Configuration

```bash
# Copy the example config (if you don't have one yet)
cp group_vars/all.yml.example group_vars/all.yml

# Open your config file
nvim group_vars/all.yml
```

**Essential settings:**

```yaml
# Required: Your name for git commits
git_user_name: "Your Full Name"

# Choose which tools to run by default
default_roles:
  - system
  - git
  # ...
```

### Apply Your Changes

```bash
# Run dotfiles again to apply your customization
./bin/dotfiles
```

## You're Done!

Your environment is now managed by Ansible. Re-run `./bin/dotfiles` after
changing `group_vars/all.yml` or role files — roles are idempotent, so only
actual changes are applied.

## What's Next?

### Daily Usage

```bash
# Update your environment anytime
./bin/dotfiles

# Install specific tools only
./bin/dotfiles -t neovim,git

# See what would change (dry run)
./bin/dotfiles --check
```

### Advanced Configuration

- [Configuration Reference](CONFIGURATION.md) - All config options
- [Configuration Examples](EXAMPLES.md) - Sample setups
- [Troubleshooting Guide](TROUBLESHOOTING.md) - Common issues and solutions
