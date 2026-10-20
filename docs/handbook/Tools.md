---
tags: [infra, tools]
---
# Tools

Back to [[Home]]. Everything is run from **WSL** in the repo root (`~/.infra`), never from PowerShell.

| Tool | Job | Talks to | Has memory? |
| --- | --- | --- | --- |
| **Make** | short names for long commands | — | no |
| **Ansible** | sets up the *inside* of machines | each host over SSH | no: it looks at the host every run |
| **Terraform** | creates things *outside* the machines: VMs, LXCs, Cloudflare routes | Proxmox API, Cloudflare API | yes: the **state** |
| **SOPS + age** | keeps secrets encrypted in git | — | — → [[Secrets]] |

## Make

`make <target>` runs the commands written under that target in `Makefile`. It is only a shortcut;
`make` alone lists all targets. When unsure what a target does, open `Makefile`: each is a few lines.

| `make …` | Really runs | Effect |
| --- | --- | --- |
| `homelab-check` | `ansible-playbook -i inventories/homelab homelab.yml --check --diff` | dry run of everything |
| `homelab` | the same without `--check --diff` | applies everything to every host |
| *(none)* | `… homelab.yml --tags apps` | only the apps VM; add `--check --diff` for its dry run |
| `homelab-lint` | syntax check, ansible-lint, terraform fmt/validate, secrets check | before every commit (CI runs it too) |
| `tf-plan` / `tf-apply` | Terraform plan/apply in `terraform/proxmox` | VMs, LXCs, shares |
| `cf-plan` / `cf-apply` | Terraform plan/apply in `terraform/cloudflare` | public routes, DNS → [[Cloudflare]] |
| `tf-restore-state` / `cf-restore-state` | decrypt the state copy from git | first thing on a new machine |
| `secret NAME=x` | `new-secret.sh` | random password into SOPS |
| `set-secret NAME=x` | `set-secret.sh` | a value you have, hidden prompt |
| `new-deploy-key NAME=x COMMENT=y` | `new-deploy-key.sh` | read-only GitHub deploy key into SOPS |
| `new-stack NAME=… IMAGE=… PORT=…` | `new-stack.sh` | scaffolds a new app |
| `ssh-config` | `ssh-config.sh --windows` | `ssh apps`, `ssh proxmox`, … for WSL and Windows |
| `dotfiles` / `dotfiles-check` | the dev-environment playbook | → [[Dev environment (dotfiles)]] |

> [!tip] `ANSIBLE_CONFIG=ansible.cfg`
> Ansible ignores `ansible.cfg` in world-writable folders such as `/mnt/c/...`. The make targets set
> it; when you type an `ansible-playbook` command yourself, put it in front.

## Ansible

Ansible connects over SSH and makes each machine look the way the repo says.

- **Inventory** `inventories/homelab/hosts.yml`: the machines and their **groups**: `proxmox` (the host),
  `docker_hosts` (the apps VM), `adguard` and `wireguard` (the LXCs). There is deliberately no default
  inventory, so a stray command cannot reach real machines: always `-i inventories/homelab`.
- **group_vars** `inventories/homelab/group_vars/<group>.yml`: settings for that group (`all.yml` for
  everyone). Roles read them, e.g. `stacks_enabled` in `docker_hosts.yml`.
- **Roles** `roles/<name>/`: the *how*. `tasks/main.yml` is the list of steps, `defaults/` default
  settings, `templates/` files with `{{ variables }}`, `handlers/` actions run when something changed
  (e.g. restart sshd).
- **Playbook** `homelab.yml`: one **play** per group, each a list of roles:

| Play | Hosts | Roles | Tag |
| --- | --- | --- | --- |
| Proxmox host | `proxmox` | ssh_access, proxmox_host, zfs_datasets, sanoid, node_exporter | `proxmox` |
| Docker host | `docker_hosts` | common, ssh_access, docker_host, node_exporter, stacks | `apps` |
| AdGuard Home | `adguard` | ssh_access, adguard, node_exporter | `adguard` |
| WireGuard | `wireguard` | ssh_access, wireguard, node_exporter | `wireguard` |

  `--tags apps` runs only that play. The plays that need secrets load them first (`community.sops.load_vars`,
  in memory only) → [[Secrets]].
- **Idempotent**: each step checks first and changes only what differs. `ok` = already right,
  `changed` = fixed something. A second run should say `changed=0`; that is also how you spot drift.
- **`--check --diff`**: a dry run that shows the would-be changes. Some steps (a Docker build) cannot be
  predicted, so a real run may show a few more.

## Terraform

Terraform describes *what should exist* and changes only the difference between that and reality.

- Two separate **roots** (folders), each with its own provider, credentials and state:
  - `terraform/proxmox` (provider `bpg/proxmox`): the pinned Ubuntu images (checksum-verified), the apps
    VM (cloud-init sets the admin user and SSH key), the two LXCs, the virtiofs shares. Credentials: the
    Proxmox API token in `terraform/proxmox/secrets.sops.env`, decrypted by `sops exec-env`.
  - `terraform/cloudflare` (provider `cloudflare/cloudflare`): tunnel routes and DNS → [[Cloudflare]].
- **plan → apply.** `plan` changes nothing: it prints `+` create, `~` change, `-` destroy, and the make
  target saves it to `tfplan.tfplan`. `apply tfplan.tfplan` does *exactly* that saved plan. Read the plan
  every time; a `-` or "must be replaced" on something holding data means stop.

### Terraform state

Terraform's **state** (`terraform.tfstate`) is its list of what it created, with their IDs. Without it,
Terraform believes nothing exists and tries to create everything again, which fails with
"already exists".

- It contains IDs and the domain, so it is **gitignored**. Git holds an **encrypted copy**,
  `terraform.tfstate.sops`, written by `tf-apply`/`cf-apply` (`scripts/homelab/tfstate.sh backup`).
  **Commit that file after every apply.**
- New machine or fresh clone: **restore before the first plan** (`make tf-restore-state`,
  `make cf-restore-state`).
- A wrong state left behind by a failed run: move it away (`mv terraform/<root>/terraform.tfstate /tmp/`)
  and restore. `restore` refuses to overwrite a state that differs from the copy, on purpose.
- Check whether the copy is current: `scripts/homelab/tfstate.sh check [cloudflare]`.

## The helper scripts

`scripts/homelab/`, all called by make targets:

| Script | Does |
| --- | --- |
| `new-secret.sh` | random value straight into SOPS, never printed |
| `set-secret.sh` | asks for a value with hidden input, stores it in SOPS |
| `new-deploy-key.sh` | SSH key pair: private half into SOPS, prints the public half for GitHub |
| `new-stack.sh` | scaffolds `stacks/<name>/compose.yml` + `roles/stacks/templates/<name>.env.j2` (refuses `:latest`) |
| `cf-terraform.sh` | runs Terraform for Cloudflare with the token, IDs and domain from SOPS in memory → [[Cloudflare]] |
| `tfstate.sh` | backup / restore / check of the encrypted state copy |
| `ssh-config.sh` | SSH host entries from the inventory, for WSL and Windows |
| `check-secrets.sh` | checks the secret files are really encrypted (CI runs it) |
| `bootstrap-secrets.sh` | one-time: built the secret files from the old live system |
