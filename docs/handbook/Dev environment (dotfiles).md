---
tags: [infra, dotfiles]
---
# Dev environment (dotfiles)

Back to [[Home]]. The second project in the repo: it installs your tools and their config on every PC
(Arch/CachyOS, Ubuntu desktop/WSL/server, Fedora). Its own detailed docs: `dotfiles/README.md` and
`dotfiles/docs/`.

## Setting up a machine

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/uarslandev/infra/main/bin/dotfiles)"
```

`bin/dotfiles`:
1. clones the repo to `~/.infra` (moves older layouts aside, deletes nothing);
2. links `~/.dotfiles` → `~/.infra/dotfiles` (the shell config expects `~/.dotfiles`) and puts a
   `dotfiles` command into `~/.local/bin`;
3. runs `dotfiles/bin/dotfiles`, which installs Ansible and runs the playbook.

That is also why your homelab clone in WSL is `~/.infra`.

## How it is built

- `dotfiles/main.yml` runs on `localhost`. Its **pre_tasks** work out the environment: the distribution
  (CachyOS counts as Arch), WSL or not, the real user, whether sudo works, whether 1Password is there.
- **One role per tool**: 91 of them in `dotfiles/roles/` (zsh, neovim, git, tmux, docker, terraform,
  obsidian, …). Each role's `tasks/main.yml` looks for `tasks/<Distribution>.yml` and runs it if it
  exists, so the same playbook works everywhere and skips what does not apply. The tool's config files
  sit next to it in `roles/<tool>/files/`.
- **Which roles run**: `default_roles` in `dotfiles/group_vars/all.yml`, minus `exclude_roles` (and per
  distribution). Your git name/email are there too.
- **Secrets** come from 1Password (`op://…` references), never from the repo; secret tasks use
  `no_log`.

## Daily use

```bash
dotfiles                   # apply everything (same as: make dotfiles)
dotfiles -t neovim         # only some roles (tags = role names)
dotfiles --check           # dry run
dotfiles --uninstall neovim
dotsave "message"          # commit + push the repo (shell helper; also: wip "message")
```

New tool = new role in `dotfiles/roles/<tool>/` (install tasks + `files/`), added to `default_roles`.

## Extras

- `dotfiles/archinstall.sh`: an interactive Arch Linux installer; the matching ISO (LTS kernel + ZFS) is
  built by the `build_arch_iso.yml` workflow.
- `dotfiles/Dockerfile` + `Taskfile.yml`: a throwaway Ubuntu container to try the playbook.

> [!note] Separate from the homelab
> Own `ansible.cfg`, roles and settings. Both projects have e.g. a `wireguard` role; they never mix.
> Run dev-environment Ansible from `dotfiles/`.
