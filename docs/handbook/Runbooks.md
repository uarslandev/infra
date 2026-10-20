---
tags: [infra, runbook]
---
# Runbooks

Back to [[Home]]. Step by step for the common jobs. Everything runs in WSL in `~/.infra`, after
`git pull`.

## Deploy a change

1. `make homelab-check`: read what would change.
2. Apply only what you touched:
   - apps / stacks: `ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags apps`
   - everything: `make homelab`
   - VMs/LXCs: `make tf-plan`, read, `make tf-apply`
   - public routes: `make cf-plan`, read, `make cf-apply`
3. `make homelab-lint`, commit (including any `terraform.tfstate.sops`), push.

## Update APEX

[[APEX on the homelab#Updating APEX]].

## Add an app

1. `make new-stack NAME=myapp IMAGE=vendor/myapp:1.2.3 PORT=8080` (pinned tag, never `:latest`).
2. Check `stacks/myapp/compose.yml`: data folder, ports, environment.
3. Secrets: `make secret NAME=myapp_db_password`; in `roles/stacks/templates/myapp.env.j2`
   `DB_PASSWORD={{ myapp_db_password }}`; in `compose.yml` `DB_PASSWORD: ${DB_PASSWORD}`.
4. Add `myapp` to `stacks_enabled` (`group_vars/docker_hosts.yml`).
5. Data that must survive: small → `/srv/appdata/myapp`; large → [[#New ZFS dataset]].
6. `make homelab-lint`, `make homelab-check`, `--tags apps` → `https://myapp.home.<domain>`.
7. `security-reviewer`, commit, push.

Your own private repo instead of an image: also a deploy key (`make new-deploy-key`), `myapp_repo` and
`myapp_version`, a copy of `roles/stacks/tasks/config/apex.yml`, and `build:` in the compose file →
[[homelab/how-deploys-work|How deploys work]].

## New ZFS dataset

1. `group_vars/proxmox.yml`: `zfs_datasets_list` (`- name: tank/x`) and `sanoid_datasets` (`tank/x: standard`).
2. `terraform/proxmox/terraform.tfvars`: `virtiofs_shares` → `x = "/tank/x"`.
3. `group_vars/docker_hosts.yml`: `docker_host_virtiofs_mounts` → `x: /srv/x`.
4. `--tags proxmox` (creates it), `make tf-plan` + `make tf-apply` (shares it), reboot the VM
   (`ssh proxmox qm reboot 110`; new virtiofs devices are not hot-plugged), `--tags apps` (mounts it).

## Make something public

1. The service listens on `127.0.0.1:<port>` on the apps VM. Never an admin UI.
2. `terraform/cloudflare/tunnel.tf`: a `local` for the hostname, an `ingress` entry **before** the final
   404 (with a `path` if only part of it should be public), a `cloudflare_dns_record` (copy `apex_web`).
3. Deploy the stack first (`--tags apps`).
4. `make cf-plan`: expect only your additions. If it wants to create existing records: state missing →
   `make cf-restore-state`. Then `make cf-apply`.
5. Commit the code + `terraform/cloudflare/terraform.tfstate.sops`, push.
6. From outside: `curl -I https://<hostname>/`, and admin paths must answer 404.

More: [[Cloudflare]].

## New device

| What | On the new device | Then |
| --- | --- | --- |
| SSH | `ssh-keygen -t ed25519 -C "<device>"`, then `make ssh-config` | add the `.pub` line to `ssh_access_authorized_keys` (`group_vars/all.yml`), `make homelab` from a device with access |
| Secrets | copy the age key from KeePass to `~/.config/sops/age/keys.txt` (`chmod 600`) | — or a new key: add its public key to `.sops.yaml`, `sops updatekeys` every `*.sops.*` from an old device |
| VPN | the WireGuard app makes a key pair | add a `[Peer]` to `wireguard_wg0_conf` (`sops secrets/homelab.sops.yml`), `--tags wireguard` |

## New machine or fresh clone

```bash
sudo apt install ansible-core ansible-lint make age     # + terraform, sops
git clone https://github.com/uarslandev/infra ~/.infra && cd ~/.infra   # or the dotfiles bootstrap
ansible-galaxy collection install -r requirements/homelab.yml
# age key to ~/.config/sops/age/keys.txt (from KeePass)
make ssh-config
make tf-restore-state && make cf-restore-state          # before any plan!
```

## Restore a file

```bash
ssh proxmox
zfs list -t snapshot -r tank/nextcloud
ls /tank/nextcloud/.zfs/snapshot/
cp -a /tank/nextcloud/.zfs/snapshot/<snap>/<path> /tank/nextcloud/<path>
```

Nextcloud afterwards: `occ files:scan` for that user. `zfs rollback` throws away everything newer: only
with an explicit OK → [[Proxmox and ZFS#Snapshots]].

## Rebuild from zero

As long as `tank` survives: reinstall Proxmox, `zpool import -f tank`, `--tags proxmox`,
`make tf-restore-state` + `tf-plan` + `tf-apply`, `make homelab`. Full list:
[[homelab/README|Homelab runbook → Rebuild from zero]].

## Emergency kit (KeePass + printout)

age key · recovery SSH key + passphrase · Proxmox root password + 2FA codes · GitHub login + 2FA codes ·
Cloudflare login + 2FA codes.
