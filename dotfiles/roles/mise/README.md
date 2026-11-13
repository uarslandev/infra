# mise Role

Installs [mise](https://mise.jdx.dev), one version manager for language runtimes (the successor
of asdf), and the global runtimes every shell gets: Node and Python, pinned in `files/config.toml`.

- The mise release is pinned and checksum-verified in `defaults/main.yml`
  (`/usr/local/bin` with sudo, otherwise `~/.local/bin`; Homebrew on macOS).
- `files/config.toml` is linked to `~/.config/mise/config.toml`; the role runs `mise install`.
- zsh activates it in `roles/zsh/files/zsh/mise_config.zsh`: interactive shells get the hook,
  other shells (agents, editors) the shims. With mise present, the nvm lazy-load wrappers are
  skipped so they don't shadow mise's `node`.

## Usage

```bash
dotfiles -t mise,zsh
mise ls                 # what is active here
mise use node@24        # pin a version for the current project (writes mise.toml)
mise use -g python@3.13 # change the global default
```

Projects can also keep `.nvmrc`, `.node-version`, `.python-version` or `.tool-versions`;
mise reads them. Upgrade the global runtimes by editing `files/config.toml`.
