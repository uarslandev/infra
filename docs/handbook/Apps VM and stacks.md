---
tags: [infra, homelab, docker]
---
# Apps VM and stacks

Back to [[Home]]. VM 110 `apps` (Ubuntu 26.04) runs every app in Docker.

## The VM

- **Created** by Terraform (`terraform/proxmox/apps_vm.tf`): 8 cores, 24 GB, a 64 GB system disk on
  `tank`, cloud-init creates your admin user with your SSH key.
- **Set up** by Ansible, play `apps`:
  - `common`: user folders, zsh;
  - `ssh_access`: key-only SSH → [[Networking#SSH]];
  - `docker_host`: timezone, unattended security upgrades, Docker Engine + Compose from Docker's apt
    repository, log rotation (`local` driver, 3 × 10 MB per container), your user in the `docker` group,
    the virtiofs mounts → [[Proxmox and ZFS#How data reaches the apps (virtiofs)]];
  - `node_exporter`: metrics;
  - `stacks`: every app.
- It holds no data of its own and can be recreated any time.

## The stacks role

A **stack** is one app: `stacks/<name>/compose.yml` plus `roles/stacks/templates/<name>.env.j2`.
Which ones run is `stacks_enabled` in `inventories/homelab/group_vars/docker_hosts.yml` (in that order);
`stacks_absent` lists retired ones to stop and remove (their data stays on ZFS).

For each enabled stack, `roles/stacks/tasks/stack.yml`:
1. creates `/opt/stacks/<name>/` (root, 0750) and copies `compose.yml` there;
2. renders `.env` from the template **with the decrypted secrets**, root-only (0600), `no_log` so it never
   shows in the output;
3. runs `roles/stacks/tasks/config/<name>.yml` if it exists (extra steps: Traefik's certificate file,
   Nextcloud's proxy settings, Prometheus/Grafana config, APEX's git clone);
4. `docker compose up`; when `.env` or the config changed, the containers are recreated.

`compose.yml` holds placeholders like `${DB_PASSWORD}`; Docker Compose fills them from `.env`.
So secrets never sit in git in plain text, and never in `compose.yml`. → [[Secrets]]

Before anything else, the role checks that the Traefik DNS token is real (so a missing token can't leave
the LAN without HTTPS) and creates the shared Docker network `proxy` that Traefik uses.

## The apps

| Stack | What | LAN name | Data |
| --- | --- | --- | --- |
| `cloudflared` | the Cloudflare Tunnel connector (host network) | — | none → [[Cloudflare]] |
| `traefik` | reverse proxy + HTTPS for every LAN name; Docker access only via a read-only socket proxy | `traefik` | `tank/appdata/traefik` → [[Networking#Traefik]] |
| `immich` | photos (server, machine learning, Valkey, Postgres with vector search) | `photos` | `tank/immich` |
| `nextcloud` | files (app, MariaDB, Redis, cron container) | `cloud` | `tank/nextcloud` |
| `jellyfin` | media server, CPU transcoding | `media` | `tank/jellyfin` |
| `syncthing` | file sync | `syncthing` | `tank/syncthing` |
| `monitoring` | Prometheus, Alertmanager, Grafana, cAdvisor, blackbox, Proxmox exporter | `grafana` | `tank/appdata` → [[Monitoring and alerts]] |
| `apex` | APEX sync server (PocketBase) + the APEX website/PWA, built from your own repo | `apex`, `apex-web` | `tank/apex` → [[APEX on the homelab]] |
| `portfolio` | the personal site uarslan.com (static Astro, Caddy), built from your own repo | `portfolio` | none (static) |
| `forge` | FORGE training app (Postgres + Fastify API + nginx/PWA), built from your own repo; only the web service is public, `/api` proxied internally | `forge` | `tank/forge` |

LAN names are `https://<name>.home.<domain>`. Versions are pinned in each `compose.yml` (never `:latest`);
Renovate proposes updates → [[CI, Renovate and agents]].

## Updating an app

- **Normal update**: Renovate opens a PR with the new version and its release notes → CI green → merge →
  `git pull` → `--tags apps`.
- **By hand**: bump the tag in `stacks/<name>/compose.yml`, read the release notes, `--tags apps`.
- Rules: **Nextcloud one major version at a time**; Immich server and machine learning always together,
  and check its release notes for database changes. Major versions wait for your OK on Renovate's
  Dependency Dashboard.

## Adding or removing an app

[[Runbooks#Add an app]]. Remove: move the name from `stacks_enabled` to `stacks_absent`, `--tags apps`.

## Looking inside

```bash
ssh apps
sudo docker ps                        # what runs, and health
sudo docker logs -f <container>       # an app's log
ls /opt/stacks/<name>/                # what Ansible deployed
```
