# How the homelab works (overview)

Read this first. Details: [README.md](README.md) (runbook), [inventory.md](inventory.md) (current state), [TODO.md](TODO.md) (open work).

## The principle: infrastructure as code

```
┌──────────────────────────────────────────────────────────────┐
│ 3. APPS      Docker Compose stacks (stacks/)   ← Ansible      │
│ 2. SYSTEMS   packages, SSH, Docker, DNS, VPN   ← Ansible      │
│ 1. MACHINES  VMs, LXCs, disks, shares          ← Terraform    │
│ 0. DATA      ZFS pool "tank"                   ← snapshots +  │
│                                                  backups      │
└──────────────────────────────────────────────────────────────┘
   Secrets for every layer: SOPS + age, encrypted in git (secrets/)
```

- **The repo is the single source of truth.** Never change servers by hand: change the repo, deploy, commit.
- **Machines are disposable, data is not.** The `apps` VM holds no data; Terraform recreates it in about a minute and
  Ansible configures it again. Only the data in `tank` is irreplaceable.

```
Admin PC / laptop (WSL)  ── git push ──►  GitHub uarslandev/infra  ◄── Renovate (update PRs)
   │ make tf-apply / make homelab             └─ CI: lint, terraform validate, secrets encrypted
   ▼
Proxmox host ── ZFS tank (mirror): immich · nextcloud · jellyfin · syncthing · appdata · apex · legacy
   ├─ VM  110 apps       Docker: Traefik · Immich · Nextcloud · Jellyfin · Syncthing · Monitoring · APEX · cloudflared
   ├─ LXC 120 adguard    LAN DNS (*.home.<domain> -> apps)
   └─ LXC 121 wireguard  VPN for access from outside
```

## The tools

| Tool | Responsible for | Typical use | Command |
| --- | --- | --- | --- |
| **Terraform** (`terraform/proxmox/`) | Machines: VMs, LXCs, disks, CPU/RAM, virtiofs shares, pinned Ubuntu images | new VM/LXC, resize, new share | `make tf-plan` → review → `make tf-apply` |
| **Terraform** (`terraform/cloudflare/`) | Public routes of the Cloudflare Tunnel + their DNS records | make something public (rarely!) | `make cf-plan` → review → `make cf-apply` |
| **Ansible** (`homelab.yml`, `roles/`) | Everything inside: packages, SSH, ZFS datasets, snapshots, Docker, apps, AdGuard, WireGuard, monitoring | after every repo change | `make homelab` / `--tags apps` |
| **SOPS + age** (`secrets/`) | Secrets, encrypted in git | new password/token | `make secret` / `make set-secret` |
| **make** (`Makefile`) | Short names for the long commands | everything above | `make help` |

### Terraform
Describes *what should exist*; compares with reality and changes only the difference. Its memory is the state file
(`terraform.tfstate`, local) with an encrypted copy in git (`terraform.tfstate.sops`, updated by `make tf-apply`).
Read every plan: `destroy`/`replace` means look twice. Auth: Proxmox API token from `terraform/proxmox/secrets.sops.env`.

### Ansible
Connects over SSH and makes each machine match the repo. Idempotent: a second run reports `changed=0` (that is also the
drift test). Layout: `inventories/homelab/hosts.yml` (which machines), `group_vars/*.yml` (settings: datasets, snapshot
policies, stacks, DNS rewrites, routes), `roles/` (how: `ssh_access`, `proxmox_host`, `zfs_datasets`, `sanoid`,
`node_exporter`, `docker_host`, `stacks`, `adguard`, `wireguard`), `homelab.yml` (which roles on which machines).
Tags: `proxmox`, `apps`, `adguard`, `wireguard`. Always `ANSIBLE_CONFIG=ansible.cfg` (the Make targets set it).

### SOPS + age
age is the encryption: the public key (`.sops.yaml`) encrypts, the private key (`~/.config/sops/age/keys.txt`, copy in
KeePass + printout) decrypts. SOPS encrypts the *values* in files, so git shows *which* secret changed but not its value.
Ansible decrypts in memory and writes `/opt/stacks/<app>/.env` on the server (root, 0600). No plain secret in git or on the PC.

```bash
make secret NAME=app_db_password                # random value into sops, never printed
make set-secret NAME=cloudflare_dns_api_token   # value you already have, hidden prompt (never paste secrets into commands)
sops secrets/homelab.sops.yml                   # edit several values
sops decrypt --extract '["grafana_admin_password"]' secrets/homelab.sops.yml
```

### make
GNU Make, a normal program (`apt install make`), reads the `Makefile` in the repo root; each target is a named command
(e.g. `make homelab` = the full ansible-playbook call). Works in WSL/Linux, not in PowerShell.

## Common tasks

### Deploy a new app
```bash
make new-stack NAME=paperless IMAGE=ghcr.io/paperless-ngx/paperless-ngx:2.20.3 PORT=8000
make secret NAME=paperless_secret_key    # if needed; reference it in roles/stacks/templates/paperless.env.j2
# add "paperless" to stacks_enabled in inventories/homelab/group_vars/docker_hosts.yml
make homelab-lint && ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags apps
git add -A && git commit -m "feat: paperless" && git push
```
Reachable at `https://paperless.home.<domain>` (LAN/VPN, valid cert). Data under `/srv/appdata/paperless` (ZFS).
Public only if a tunnel route is added on purpose (`terraform/cloudflare/tunnel.tf`, then `make cf-plan && make cf-apply`),
and then only the paths the app really needs (APEX: `^/api/`). Check from outside afterwards that admin paths answer 404.

### New ZFS dataset (for a large app)
1. `group_vars/proxmox.yml` → `zfs_datasets_list`: `- name: tank/<x>`
2. same file → `sanoid_datasets`: `tank/<x>: standard` (or `critical`)
3. `terraform/proxmox/terraform.tfvars` → `virtiofs_shares`: `<x> = "/tank/<x>"`
4. `group_vars/docker_hosts.yml` → `docker_host_virtiofs_mounts`: `<x>: /srv/<x>`

Then `--tags proxmox` (create), `make tf-plan && make tf-apply` (share), reboot the VM (`ssh proxmox qm reboot 110`,
new virtiofs devices are not hot-plugged), `--tags apps` (mount).

### Updates
Renovate PR (with release notes) → CI green → merge → `make homelab`. Major versions wait on the Dependency Dashboard.

## Backups

| Layer | Protects against | Status |
| --- | --- | --- |
| ZFS mirror | one disk failing | active |
| sanoid snapshots (Immich/Nextcloud: 24 hourly, 14 daily, 8 weekly, 6 monthly) | mistakes, deleted files, bad updates | active |
| `tank/legacy` + holds | pre-rebuild DB dumps | kept until backups exist |
| copy outside the pool (PBS on USB disk) | pool loss, ransomware, `zfs destroy` | **missing** (TODO, needs the disk) |
| offsite (old server at a second location) | fire, theft | later |

Snapshots are not backups (same disks). Restore a single file from a snapshot:
```bash
ssh proxmox
zfs list -t snapshot -r tank/nextcloud
ls /tank/nextcloud/.zfs/snapshot/          # every snapshot is a read-only directory
cp -a /tank/nextcloud/.zfs/snapshot/<snap>/data/<user>/files/<file> /tank/nextcloud/data/<user>/files/
# Nextcloud: then run occ files:scan for that user
```
`zfs rollback` discards everything newer than the snapshot: destructive, only with explicit OK.

## Access from another device (laptop)
```bash
sudo apt install ansible-core ansible-lint make age        # + terraform (HashiCorp apt repo) + sops (GitHub release)
git clone https://github.com/uarslandev/infra && cd infra
ansible-galaxy collection install -r requirements/homelab.yml
# age key: copy the 3 lines from KeePass to ~/.config/sops/age/keys.txt; chmod 600
# SSH key: ssh-keygen -t ed25519 -C <device>; add the .pub line to group_vars/all.yml; run make homelab once from a device with access
make ssh-config          # ssh proxmox / apps / adguard / wireguard
make tf-restore-state
```
From outside: connect WireGuard first (add a `[Peer]` for the device in `wireguard_wg0_conf` via sops), then it is the same as at home.

### Emergency kit (KeePass + printout)
age key · recovery SSH key + passphrase · Proxmox root password + 2FA recovery codes · GitHub login + 2FA codes ·
Cloudflare login + 2FA codes. With these and GitHub everything can be rebuilt (README → "Rebuild from zero"),
as long as the data in `tank` (or its backup) survives.

## What changed in the 2026-10 rebuild

| Before | Now |
| --- | --- |
| hand-built Fedora VM, images on `:latest` | Terraform + Ansible, pinned versions, Renovate |
| VM disks on the full, 13-year-old boot SSD | disks on the ZFS mirror, boot SSD at ~7 % |
| 7,300 snapshots, none for Nextcloud for 3 months | clear sanoid policies, Immich/Nextcloud hourly |
| plain-text secrets in `.env` files | SOPS + age in git |
| SSH root login with password | key-only + offline recovery key + 2FA on the web UI |
| NPM over HTTP, `.home` names | Traefik, Let's Encrypt wildcard, HTTPS everywhere, admin UIs LAN/VPN-only |
| Grafana accidentally public, SSH via tunnel | only the APEX API public (`^/api/`), routes + DNS in Terraform |
| no monitoring | Prometheus + Grafana + e-mail alerts (ZFS, SMART, services, cert expiry) |
| hand-made DNS rewrites | AdGuard rewrites in the repo |
| no docs | README, overview, inventory, TODO, CI on every push |

Next steps toward full industry standard (in TODO.md): PBS backups, central logs (Loki),
GitOps deploys (self-hosted runner), nightly drift check, local gitleaks pre-commit.
