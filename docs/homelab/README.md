# Homelab as code

Proxmox VE host with a ZFS mirror (`tank`). Everything except the data on `tank` can be rebuilt from this repo.

How it works: [OVERVIEW.md](OVERVIEW.md). Open work: [TODO.md](TODO.md).

## Architecture

```
Proxmox VE (boot SSD: OS only)
├── ZFS pool "tank" (2 × 2 TB mirror)  ← the only thing that holds data
│   ├── tank/immich      Immich library + Postgres        (critical)
│   ├── tank/nextcloud   Nextcloud html, data, MariaDB    (critical)
│   ├── tank/appdata     small app state: Traefik (ACME), Prometheus, Alertmanager, Grafana
│   ├── tank/jellyfin    media, config, cache
│   ├── tank/syncthing   config + data
│   └── tank/apex        APEX sync server (PocketBase database + uploads)
├── VM 110 "apps" (Ubuntu 26.04, Docker)       Terraform + Ansible
│   └── datasets mounted via virtiofs at /srv/<name>; stacks in /opt/stacks/<name>
├── LXC 120 "adguard"   (Ubuntu 26.04)         LAN DNS
└── LXC 121 "wireguard" (Ubuntu 26.04)         VPN for admin access
```

- **Public access**: Cloudflare Tunnel (`cloudflared` stack, host network). Routes and their DNS records are Terraform
  (`terraform/cloudflare/tunnel.tf`, `make cf-plan && make cf-apply`); that file owns the tunnel's whole route list, so
  routes added in the dashboard disappear on the next apply. Only public route: `apex-api.<domain>`, paths `^/api/`
  (APEX sync API; superuser sign-in is blocked there too). Admin UIs are never routed through it.
- **LAN names**: `https://<name>.home.<domain>` (photos, cloud, media, grafana, syncthing, proxmox, adguard, traefik).
  AdGuard resolves `*.home.<domain>` to the apps VM (rewrites managed in `inventories/homelab/group_vars/adguard.yml`);
  Traefik terminates TLS with a Let's Encrypt wildcard cert (DNS-01 via Cloudflare) and routes by Docker labels.
  Admin UIs are LAN/VPN only (`lan-only` middleware). Old `*.home` names redirect to the new ones.
- **Admin access from outside**: WireGuard.
- **Monitoring**: Prometheus + Alertmanager + Grafana (`stacks/monitoring`, Grafana on port 3000 of the apps VM,
  user `admin`, password: `sops decrypt --extract '["grafana_admin_password"]' secrets/homelab.sops.yml`).
  Every host runs `prometheus-node-exporter` (ZFS + SMART on the Proxmox host); HTTP/DNS checks via blackbox;
  Proxmox via a read-only `pve-exporter@pve` token. Alerts (rules in `stacks/monitoring/config/prometheus/rules/`)
  are e-mailed via Gmail SMTP once `alert_email_to`, `alert_smtp_username` and `alert_smtp_password`
  (a Gmail app password, not the account password) are in `secrets/homelab.sops.yml`.
- **Updates**: Renovate (`renovate.json`) opens PRs for new image/provider/collection versions; majors need approval.
- Guest disks live on `tank`, never on the boot SSD. Infra uses the router as DNS, so it does not depend on AdGuard.

| Tool | Responsibility |
| --- | --- |
| Terraform (`terraform/proxmox`) | Ubuntu images (pinned + checksum), VM/LXCs, virtiofs directory mappings, cloud-init bootstrap |
| Terraform (`terraform/cloudflare`) | Tunnel routes + their DNS records (token `cloudflare_terraform_api_token`: Tunnel Edit, DNS Edit, Zone Read) |
| Ansible (`homelab.yml`) | Proxmox host packages, ZFS datasets, sanoid, Docker, stacks, AdGuard, WireGuard |
| SOPS + age (`secrets/`, `terraform/proxmox/secrets.sops.env`) | All secrets, encrypted in git; the age key only lives on the admin PC |

## Day-to-day

New to this? [how-deploys-work.md](how-deploys-work.md) walks through deploys, secrets and adding an app.

Run from WSL/Linux in the repo root (needs `~/.config/sops/age/keys.txt`):

```bash
make tf-plan && make tf-apply   # VMs / LXCs
make homelab-check              # Ansible dry run
make homelab                    # apply everything
ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags apps   # only the apps VM
make homelab-lint               # before committing
```

- Edit secrets: `sops secrets/homelab.sops.yml`.
- New service: `make new-stack NAME=app IMAGE=vendor/app:1.2.3 PORT=8080`, adjust the generated files, add the name to
  `stacks_enabled`, run `--tags apps`. Retire one: move it to `stacks_absent`.
- Upgrade a service: bump the pinned tag in `stacks/<name>/compose.yml`, read the release notes, run `--tags apps`.
  Nextcloud: one major version at a time. Immich: check the release notes for DB changes.
- `ansible.cfg` is ignored in world-writable dirs such as `/mnt/c/...`; always set `ANSIBLE_CONFIG=ansible.cfg` (the Make targets do).

### APEX sync server

PocketBase from the private repo `uarslandev/apex` (`server/`). Nothing from that repo is copied here: Ansible clones
the commit pinned in `apex_version` (`group_vars/docker_hosts.yml`) to `/opt/stacks/apex/src` with a read-only deploy
key (`apex_deploy_key`, made with `make new-deploy-key`), and compose builds the image on the VM. Data: `tank/apex`
(`/srv/apex/pb_data`, uid 10090). Rate limits and the trusted `CF-Connecting-IP` header come from a migration in that repo.
Traefik strips that header from LAN requests; other containers on the `proxy` network could still set it (accepted risk:
it only skews rate limits and logged IPs).

- Upgrade: set `apex_version` to the new commit, run `--tags apps` (new tag = new build).
- LAN: `https://apex.home.<domain>` (API + admin UI). Public: `https://apex-api.<domain>/api/` only.
- Admin from outside: WireGuard, or `ssh -L 8090:127.0.0.1:8090 apps`, then `http://127.0.0.1:8090/_/`.
- First admin: while none exists, PocketBase prints a one-time `/_/#/pbinstall/...` link in `sudo docker logs apex-pocketbase`
  (restart the container for a fresh one). Open it through the SSH tunnel (replace `0.0.0.0` with `127.0.0.1`) and set
  the password there, so it never lands in a shell history, chat or git.
- Backups: sanoid snapshots of `tank/apex` (crash-consistent SQLite); before upgrades also take a PocketBase backup in the admin UI.

## Access

- **SSH is key-only on every host** (role `ssh_access`): no password login, root only with a key. `authorized_keys`
  is managed exclusively from `ssh_access_authorized_keys` in `inventories/homelab/group_vars/all.yml`
  (public keys only; one per device + one offline recovery key). On Proxmox the node's own root key is always kept.
- **Break-glass** if every device is lost (keep these in KeePass + a printed copy):
  1. Proxmox web UI (LAN/VPN, port 8006): root password + TOTP → host shell, and a console for every VM/LXC (`pct enter <id>`).
  2. Physical console on the server (root password).
  3. Offline recovery SSH key (ed25519 with passphrase), never stored on a device.
  4. The age key (`AGE-SECRET-KEY-1...`) to decrypt the secrets in this repo.
  The apps VM holds no data: if needed, recreate it with Terraform using a new key.

New device:

| What | On the new device | Then |
| --- | --- | --- |
| SSH | `ssh-keygen -t ed25519 -C "<device>"`, then `make ssh-config` | add the `.pub` line to `ssh_access_authorized_keys`, run `make homelab` from a device that has access |
| sops/age | `age-keygen -o ~/.config/sops/age/keys.txt` | add the public key to `.sops.yaml`, run `sops updatekeys <file>` for every `*.sops.*` file from an old device, commit |
| WireGuard | the WireGuard app generates a key pair | add a `[Peer]` with its public key to `wireguard_wg0_conf` (`sops secrets/homelab.sops.yml`), run `--tags wireguard` |

Remove a device: delete its key from the list / `.sops.yaml` and re-run; rotate the secrets it could read.

Recovery SSH key (once, on a trusted machine): `ssh-keygen -t ed25519 -C recovery-offline -f recovery_ed25519`
(with a passphrase), store both files in KeePass, add the `.pub` line to the list, delete the local files.

## Secrets workflow

All secrets live in `secrets/homelab.sops.yml`; `.env` files are never committed or written by hand. Ansible renders
`roles/stacks/templates/<stack>.env.j2` with the decrypted values into `/opt/stacks/<stack>/.env` (root, 0600).

```bash
make secret NAME=paperless_db_password      # random value straight into sops, never printed
make set-secret NAME=cloudflare_dns_api_token   # value you already have: hidden prompt, never in history
sops secrets/homelab.sops.yml                # edit several values in an editor
sops decrypt --extract '["name"]' secrets/homelab.sops.yml   # read one value
```

## Snapshots and backups

- sanoid snapshots (policies in `inventories/homelab/group_vars/proxmox.yml`): Immich/Nextcloud hourly 24, daily 14, weekly 8, monthly 6.
- `@pre-rebuild-20261015` snapshots of every dataset; Immich, Nextcloud and legacy are protected with `zfs hold keep`.
- DB dumps from the migration: `/tank/legacy/db/` (root-only). Old configs: `/tank/legacy/`.
- **Open**: second ZFS target (syncoid) and offsite (restic) are not set up yet. Until then the only copy is the pool itself.

## Rebuild from zero

Assumes the `tank` pool is intact. If the boot SSD dies: reinstall Proxmox VE, then `zpool import -f tank`.

1. **Admin PC** (WSL/Linux): install `ansible-core`, `ansible-lint`, `terraform`, `sops`, `age`, `make`; restore the age key to
   `~/.config/sops/age/keys.txt` (from your password manager / offline backup, never from git).
   `ansible-galaxy collection install -r requirements/homelab.yml`.
2. **Proxmox host**: `pveam update`, SSH key for root, then
   `ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags proxmox`.
3. **Terraform token** (only if the host was reinstalled): `scripts/homelab/bootstrap-secrets.sh token`.
4. **Guests**: `make tf-restore-state` (if this machine has no state yet), `make tf-plan`, review, `make tf-apply`.
5. **Services**: `make homelab`. Stacks start on the existing data in `tank`.
6. **Check**: Immich `http://<apps>:2283`, Nextcloud `http://<apps>:8080/status.php` (`maintenance:false`),
   `docker ps` all healthy, `wg show` on the WireGuard LXC lists all peers, DNS answers from AdGuard.

If the data itself has to be restored: roll back to a snapshot (`zfs rollback`) or import the DB dump
(`/tank/legacy/db/*.sql.gz`) into a freshly started database container of the **same** major version.

## Known quirks

- Ubuntu's `wg-quick` AppArmor profile crashes wg-quick inside unprivileged LXCs; the `wireguard` role disables that one profile in LXCs.
- In LXCs, `/etc/resolv.conf` is written by Proxmox; don't replace it.
- Terraform only uses `<type> <key>` of `~/.ssh/id_rsa.pub`: a multi-line key comment broke cloud-init once.
- Terraform state is local (`terraform/proxmox/terraform.tfstate`, gitignored); an encrypted copy
  (`terraform.tfstate.sops`, one opaque SOPS blob) is updated by `make tf-apply` and committed.
  New machine: `make tf-restore-state` before the first plan. Check: `scripts/homelab/tfstate.sh check`.
