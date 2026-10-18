# tldr

Installs [tldr](https://tldr.sh/), simplified man pages with practical examples.

- **macOS**: Homebrew (C client)
- **Ubuntu**: GitHub releases (tldr-hs, x86_64 only; skipped on `aarch64` since no upstream binary is published)

## Usage

```bash
dotfiles -t tldr
tldr tar
tldr --update  # Update cache
```
