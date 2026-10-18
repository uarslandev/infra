# CLAUDE.md

This repo (`uarslandev/infra`, public) holds all infrastructure, as two separate Ansible projects:

1. **Dev environment / dotfiles** (`dotfiles/`, own `main.yml`, `ansible.cfg`, `roles/`, `group_vars/`): installs every
   tool and its config on Arch, Ubuntu (desktop/WSL/server) and Fedora. Entry point `bin/dotfiles`:
   `bash -c "$(curl -fsSL https://raw.githubusercontent.com/uarslandev/infra/main/bin/dotfiles)"` must keep working.
   It clones to `~/Repos/infra` and links `~/.dotfiles` -> `~/Repos/infra/dotfiles` (shell config uses `~/.dotfiles`).
   New program = new role in `dotfiles/roles/<tool>/` (install tasks + `files/` with its config). Its own notes:
   `dotfiles/AGENTS.md`. Ask before changing this part.
2. **Homelab as code**: `homelab.yml`, `inventories/homelab/` (always passed with `-i`; `ansible.cfg` sets no default
   inventory), roles (`common`, `ssh_access`, `proxmox_host`, `zfs_datasets`, `sanoid`, `node_exporter`, `docker_host`,
   `stacks`, `adguard`, `wireguard`), `stacks/`, `terraform/proxmox/`, `terraform/cloudflare/`, `secrets/`,
   `scripts/homelab/`, `docs/homelab/`. Only run explicitly. Start with `docs/homelab/README.md`.

The two projects never share roles or vars (both have e.g. a `wireguard` role); run dev-env Ansible from `dotfiles/`.

## Rules

- **Read-only first.** Inspect before changing. Ask before any command that changes a system (remote or local).
- **Destructive commands need an explicit OK in chat for that exact command**: `zfs destroy`, `zfs release`, `zpool` changes,
  `qm destroy`, `pct destroy`, `rm -rf` on data, `wipefs`, partitioning, `terraform destroy`/replacing resources
  that hold data, and anything else that can lose data.
- **Immich and Nextcloud data (`tank/immich`, `tank/nextcloud`) must never be lost.** Their `@pre-rebuild-20261015`
  snapshots carry a `zfs hold`; never release it without an explicit OK. Downtime is fine.
- **The repo is public.** Secrets only via SOPS + age (the age private key stays on the admin PC, never committed).
  Never put tokens, passwords, private keys or other secrets in chat or git, not even in examples or history.
  Keep internal details minimal (no public IPs, no personal domain names, no MACs/serials). Private LAN IPs are OK.
- **Small, reviewable steps.** Plan first, one logical change per commit, explain each step in plain language.
- **Ask before adding new tools** (CLIs, providers, collections, services).
- **Pin versions** (container images, Terraform providers, Ansible collections). No `:latest`.
- SSH is key-only everywhere (role `ssh_access`). Never remove the last key or the Proxmox node key; test changes with an
  open safety session (`ssh -o ControlMaster=yes -o ControlPersist=20m -fN ...`) before reloading sshd.
- Before committing homelab changes: `make homelab-lint` (syntax, ansible-lint production, terraform fmt/validate, secrets encrypted).

## Gotchas

- Run Ansible/Terraform from WSL. `ansible.cfg` is ignored in world-writable dirs (`/mnt/c/...`): always set `ANSIBLE_CONFIG=ansible.cfg`.
- Terraform auth: `sops exec-env terraform/proxmox/secrets.sops.env '<terraform cmd>'`. State is local (gitignored) with an
  encrypted copy `terraform/proxmox/terraform.tfstate.sops`: always apply via `make tf-apply` and commit that file.
  Cloudflare (tunnel routes + DNS): `make cf-plan` / `make cf-apply` (credentials from `secrets/homelab.sops.yml`, state copy
  `terraform/cloudflare/terraform.tfstate.sops`). After any route change, check from outside that admin paths answer 404.
- Agents in `.claude/agents/`: `devops-engineer`, `qa-engineer` (requirements + verification), `security-reviewer` (run before commits).
