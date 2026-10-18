# vscode

Installs Visual Studio Code (branded build) on every supported distribution.

| Distribution | Source |
|--------------|--------|
| Archlinux / CachyOS | AUR `visual-studio-code-bin` |
| Ubuntu | Microsoft apt repository (`code`) |
| Fedora | Microsoft dnf repository (`code`) |
| macOS | Homebrew cask `visual-studio-code` |

## Usage

```bash
dotfiles -t vscode
```

Add `vscode` to `default_roles` in `group_vars/all.yml` to install it by default.

## Notes

- Settings, keybindings, and extensions are user-level state and are not
  managed by this role - configure VS Code directly or add an extensions
  list task if you want them automated.
- The AUR build uses `kewlfft.aur` (paru/yay if present, otherwise makepkg).
