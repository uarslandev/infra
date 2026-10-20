---
tags: [infra, homelab, apex]
---
# APEX on the homelab

Back to [[Home]]. APEX is the one app built from your **own** code (the private repo `uarslandev/apex`)
instead of a published image.

## Two services, one stack (`stacks/apex`)

| Service | What | Listens on | Public as |
| --- | --- | --- | --- |
| `pocketbase` | the sync server (accounts, training data) | `127.0.0.1:8090` | `apex-api.<domain>`, only `^/api/` |
| `web` | the website and the PWA (static files, Caddy) | `127.0.0.1:8091` | `apex.<domain>` |

Both run non-root, on a read-only filesystem, with every Linux capability dropped. On the LAN:
`https://apex.home.<domain>` (API + admin UI) and `https://apex-web.home.<domain>` (website).

## How your code gets onto the server

`roles/stacks/tasks/config/apex.yml`, before `docker compose up`:
1. puts the **read-only deploy key** (`apex_deploy_key` from SOPS) and GitHub's pinned host key on the VM;
2. clones `uarslandev/apex` at **exactly** the commit `apex_version` (in `docker_hosts.yml`) into
   `/opt/stacks/apex/src`;
3. prepares `/srv/apex/pb_data` for the unprivileged user (uid 10090).

Then Compose **builds** both images on the VM: `server/Dockerfile` (PocketBase, pinned and
checksum-verified) and `website/Dockerfile` (builds the PWA with a pinned Flutter, then Caddy). The image
tags are the commit, so a new commit means a new build.

## Updating APEX

1. In the APEX repo: commit and push.
2. Here: set `apex_version` to the new full commit hash, commit, push.
3. `make homelab-check`, then `--tags apps`. PocketBase applies new migrations at start.
4. `curl -s https://apex-api.<domain>/api/health`.

Before an update that changes the database, take a PocketBase backup in its admin UI. Rolling back = set
the old hash and deploy (a migration that already ran is not undone by that).

## Settings and secrets

`.env` (from `roles/stacks/templates/apex.env.j2`): version, uid, and the mail settings
(`apex_smtp_*`, `apex_mail_from`, `apex_app_url`). With `apex_smtp_host` empty, mail is off and new
accounts are confirmed by hand in the admin UI. The SMTP password would be the secret
`apex_smtp_password`.

## Admin access

The admin UI (`/_/`) is never public. On the LAN: `https://apex.home.<domain>/_/`. From anywhere:
`ssh -L 8090:127.0.0.1:8090 apps`, then `http://127.0.0.1:8090/_/`. The first admin is created once with
the one-time link PocketBase prints in `sudo docker logs apex-pocketbase` → [[homelab/README|runbook]].

## Data and backups

`tank/apex`, `standard` snapshot policy → [[Proxmox and ZFS#Snapshots]].
