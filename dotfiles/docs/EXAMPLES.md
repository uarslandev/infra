# Configuration Examples

## Quick Configuration Templates

### Minimal Developer Setup

```yaml
git_user_name: "Your Full Name"

default_roles:
  - system
  - 1password
  - fonts
  - git
  - bash
  - neovim
  - tmux
  - fzf
  - starship
  - bat
  - lsd
  - zoxide
```

### Full Setup (this repo's default)

```yaml
git_user_name: "Your Full Name"

default_roles:
  - system
  - 1password
  - fonts
  - git
  - bash
  - neovim
  - tmux
  - fzf
  - starship
  - bat
  - lsd
  - zoxide
  - btop
  - ncdu
  - gh
  - lazygit
  - python
  - nvm  # Must run before npm
  - npm
  - go
  - rust
  - terraform
  - docker
  - ssh
  - sshfs
  - taskfile
  - tldr
  - opencode
```

### Server (headless, no desktop tools needed)

Same as the full setup — every role is CLI-only, so nothing desktop-specific
runs. Package roles with no task file for your distro are skipped silently.

## 1Password Configuration Examples

### Basic 1Password Setup

```yaml
op_account: my.1password.com

op:
  git:
    user:
      email: "op://Personal/GitHub/email"
```

### Full 1Password Setup (git + SSH keys + signing)

```yaml
op_account: my.1password.com

op:
  git:
    user:
      email: "op://Personal/GitHub/email"
    allowed_signers: "op://Personal/GitHub SSH/allowed_signers"
  ssh:
    github:
      personal:
        - name: id_ed25519
          vault_path: "op://Personal/GitHub SSH"
```

## Common Mistakes to Avoid

### Don't do this:

```yaml
# Missing git_user_name (required)
default_roles:
  - git

# Invalid role name (role doesn't exist)
default_roles:
  - zsh
```

### Do this instead:

```yaml
# Always include git_user_name
git_user_name: "Your Full Name"
default_roles:
  - git

# Proper 1Password vault reference
op:
  git:
    user:
      email: "op://Personal/GitHub/email"
```

## Testing Your Configuration

```bash
# Validate syntax
ansible-playbook main.yml --syntax-check

# Dry run (see what would change)
./bin/dotfiles --check

# Run specific roles only
./bin/dotfiles -t git,neovim

# Run with verbosity to debug issues
./bin/dotfiles -t git -vvv
```

## Updating Your Configuration

```bash
# Edit your configuration
nvim group_vars/all.yml

# Apply changes
./bin/dotfiles
```
