# Neovim Role

Installs Neovim (>= 0.12) and links `~/.config/nvim` to this role's `files/` directory.

The config is [craftzdog's (devaslife)](https://github.com/craftzdog/dotfiles/tree/master/dot_config/nvim)
Neovim setup, copied from upstream commit `7c50fa7`. It changes very little, and every change is marked
with an `infra:` comment:

- **More languages.** Go, Python, Bash, YAML, Ansible, Terraform, Docker, JSON, PowerShell, Ruby,
  Astro, GraphQL and Svelte language servers and parsers, on top of his TS/Lua/Rust/CSS/Tailwind list.
  TypeScript uses his `vtsls`, not `ts_ls`. Python gets ruff for linting and formatting next to pyright.
- **POSIX lazygit command.** His lazygit "open file in the pane it came from" command is written for fish;
  ours is POSIX sh, so it works under zsh/bash.
- **`lua/infra/filetypes.lua`.** Ansible YAML detection (by path and content), Terraform vars and justfiles.

To pull in a newer upstream version, diff `files/` against his `dot_config/nvim/` and keep the
`infra:` blocks.

## Plugins and pinning

Plugins are managed by Neovim's built-in `vim.pack` (no lazy.nvim). They are listed in
`lua/craftzdog/plugins/init.lua`, and `nvim-pack-lock.json` pins each one to an exact commit.
Commit that lockfile whenever it changes.

- Update: `:lua vim.pack.update()`, review the changes, `:w` to apply, then commit `nvim-pack-lock.json`.
- Language servers, formatters and linters: Mason (`:Mason`), installed on first start.
- Copilot: run `:Copilot auth` once (needs a GitHub Copilot subscription).

## The agentic workflow

No AI chat runs inside Neovim. The agent (Claude Code, Codex, ...) runs in a
[herdr](https://herdr.dev/) pane next to Neovim, and you use Neovim to steer it and review what it changed.

1. Open the project in herdr with Neovim on the left and the agent on the right.
2. Run `ide` (installed by the `herdr` role) in the agent pane: it keeps Neovim on top and adds
   three small shells below it, for tests, a watcher and git.
3. Point the agent at code: `<leader>yf` copies `path:line` and visual `<leader>cc` copies the selection
   as a fenced code block, ready to paste into the agent.
4. Review its changes:
   - `<leader>gd`: overlay the diff in the current buffer (mini.diff). `]c` / `[c` jump between hunks.
   - `<leader>dv`: full review in CodeDiff (file tree plus side-by-side diff).
     `<leader>dh` / `<leader>dH`: history of this file / the whole repo.
   - `;h`: pick a changed hunk. `<leader>gh` / `<leader>gs`: stage a hunk / the whole buffer.
   - `;g`: lazygit (files opened from it land back in your pane). In herdr, `prefix+alt+g` opens
     lazygit in its own pane.

The same loop works for katas and LeetCode: keep the problem in a local file, write your solution in
Neovim, run the tests in one of the bottom panes, and ask the agent for hints or a review of your diff.

## Keys worth knowing

Leader is `<Space>`. Press it (or `;`, `s`, `g`, ...) and wait a moment: which-key lists every
mapping that follows, so you don't have to remember this table.

| Key | Action |
| --- | --- |
| `;f` / `;r` | Find files / live grep (snacks picker) |
| `\\` | Buffers |
| `;;` | Resume the last picker |
| `;e` | Diagnostics |
| `sf` | File explorer (oil, floating) |
| `ss` / `sv`, `sh/sj/sk/sl` | Split / move between windows |
| `te`, `<Tab>` / `<S-Tab>` | New tab, next / previous tab |
| `gd`, `gr`, `gy`, `gI`, `K` | Definition, references, type definition, implementation, hover |
| `<leader>ca` / `<leader>cr` | Code action / rename |
| `<leader>f` | Format (format on save is on; `:ToggleFormatter` turns it off for a buffer) |
| `<C-j>` | Next diagnostic |
| `<leader>gb` / `<leader>gB` | Blame line / blame buffer |
| `<C-l>` (insert) | Accept the Copilot suggestion |

Note: the mouse is off, `x` and `<leader>d`/`<leader>c` don't overwrite the yank register, and
`+`/`-` increment/decrement numbers (his defaults).

## Requirements

Installed by this and other roles: `git`, a C compiler, `tree-sitter` CLI, `ripgrep`, `fd`, `lazygit`,
a Nerd Font and a true-color terminal. `solargraph` (Ruby) only installs once Ruby is present.

## Usage

```bash
dotfiles -t neovim
```

The first start installs all plugins, parsers and language servers (a few minutes). The plugins of
the old lazy.nvim config stay in `~/.local/share/nvim/lazy/` until you delete that folder yourself.

## Tests

`tests/test_lsp_servers.py` checks that every language server the `bun` role installs is either
enabled in Neovim or explicitly listed as not used there:

```bash
python3 roles/neovim/tests/test_lsp_servers.py
```
