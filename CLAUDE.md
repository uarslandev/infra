# CLAUDE.md

This repo (`uarslandev/infra`, public) has two parts:

1. **Dev environment / dotfiles** (`bin/dotfiles`, `main.yml`, `site.yml`, `inventory.ini`, `roles/{common,workstation,devops_tools,dotfiles}`, `pre_tasks/`).
   The `curl | bash` bootstrap in `bin/dotfiles` must keep working unchanged. It runs `ansible-playbook main.yml`
   with `ansible.cfg` (default inventory `inventory.ini`) — do not move or repurpose those files.
   Ask before changing anything in this part.
2. **Homelab as code**: `homelab.yml`, `inventories/homelab/`, `playbooks/homelab/`, homelab roles
   (`ssh_access`, `proxmox_host`, `zfs_datasets`, `sanoid`, `node_exporter`, `docker_host`, `stacks`, `adguard`, `wireguard`), `stacks/`, `terraform/proxmox/`,
   `secrets/`, `scripts/homelab/`, `docs/homelab/`. Only run explicitly. Start with `docs/homelab/README.md`.

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
- **Ask before adding new tools** (CLIs, providers, collections, services) or changing the dev-env part.
- **Pin versions** (container images, Terraform providers, Ansible collections). No `:latest`.
- SSH is key-only everywhere (role `ssh_access`). Never remove the last key or the Proxmox node key; test changes with an
  open safety session (`ssh -o ControlMaster=yes -o ControlPersist=20m -fN ...`) before reloading sshd.
- Before committing homelab changes: `make homelab-lint` (syntax, ansible-lint production, terraform fmt/validate, secrets encrypted).

## Gotchas

- Run Ansible/Terraform from WSL. `ansible.cfg` is ignored in world-writable dirs (`/mnt/c/...`): always set `ANSIBLE_CONFIG=ansible.cfg`.
- Terraform auth: `sops exec-env terraform/proxmox/secrets.sops.env '<terraform cmd>'`. State is local and gitignored.
- Agents in `.claude/agents/`: `devops-engineer`, `qa-engineer` (requirements + verification), `security-reviewer` (run before commits).
