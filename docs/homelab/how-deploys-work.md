# How deploys work

A walkthrough for the owner: what happens when you deploy, where secrets live, what each make target runs,
how Terraform and Cloudflare fit in, and how to add a new app or a public route.
The short reference is in [README.md](README.md) (Day-to-day, Secrets workflow).

## The idea

Nothing is installed on the server by hand. This repo describes the server; one command makes the server match it.

```
Your PC (WSL, repo root)                      VM "apps"
────────────────────────                      ──────────────────────────
repo: what should run      ── Ansible ──▶      /opt/stacks/<name>/
age key: unlocks secrets      (over SSH)          compose.yml
                                                  .env  (secrets, root 0600)
                                               docker compose up
```

The repo is the truth: a change made by hand on the server is overwritten by the next run.

## The four building blocks

1. **A stack = one app = one folder.**
   - `stacks/<name>/compose.yml`: containers, ports, data folder. No secrets, only placeholders like `${DB_PASSWORD}`.
   - `roles/stacks/templates/<name>.env.j2`: the template for `.env`; it fills the placeholders, e.g.
     `DB_PASSWORD={{ myapp_db_password }}`.
2. **What runs**: `stacks_enabled` in `inventories/homelab/group_vars/docker_hosts.yml`. Stacks moved to
   `stacks_absent` are stopped and removed (their data stays). Settings that are not secret live there too
   (e.g. `apex_version`).
3. **Secrets**: `secrets/homelab.sops.yml`, encrypted with SOPS + age. Names are readable, values are not. Only the
   age private key (`~/.config/sops/age/keys.txt`, never in git) decrypts it, which is why the file can sit in a
   public repo.
   - `make secret NAME=x`: random value (database passwords).
   - `make set-secret NAME=x`: a value you already have (API key, SMTP key), hidden prompt.
   - `sops secrets/homelab.sops.yml`: edit the decrypted file in an editor.
4. **The way in.**
   - LAN: Traefik serves every stack at `https://<name>.<local domain>`, through the labels in its compose file.
   - Internet: only what `terraform/cloudflare/tunnel.tf` routes through the Cloudflare Tunnel. Anything not listed
     there is not public. Change it with `make cf-plan`, then `make cf-apply`.

## What a deploy does

`make homelab` (everything) or `--tags apps` (only the apps VM):

1. Ansible decrypts the SOPS file in memory only.
2. It connects to the VM over SSH.
3. For each stack in `stacks_enabled` (`roles/stacks/tasks/stack.yml`):
   - creates `/opt/stacks/<name>/` and copies `compose.yml`;
   - renders `.env` from the template with the secrets: root, 0600, `no_log` keeps it out of the output;
   - runs `roles/stacks/tasks/config/<name>.yml` if it exists (extra steps, e.g. APEX's git clone);
   - runs `docker compose up`, and recreates the containers if `.env` changed.
4. Removes the stacks in `stacks_absent`.

`make homelab-check` is the same as a dry run: it shows what would change and changes nothing. Run it first.

## APEX: your own code instead of a ready image

Most stacks use a published image pinned to a version. APEX is built from the private repo, so
`roles/stacks/tasks/config/apex.yml` adds:

1. the read-only deploy key (secret `apex_deploy_key`) and GitHub's pinned host key;
2. a clone of `uarslandev/apex` at exactly the commit `apex_version` into `/opt/stacks/apex/src`;
3. `build: ./src/server` in its compose file, so Docker builds the image on the VM.

Updating APEX:

1. In the APEX repo: commit and push.
2. Here: set `apex_version` to the new full commit hash, commit and push.
3. `make homelab-check`, then
   `ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags apps`.
4. `curl -s https://apex-api.<domain>/api/health`.

PocketBase applies new migrations at start. Before an upgrade that changes the schema, take a backup in the admin
UI. Rolling back: set the old hash again and deploy (a migration that already ran is not undone by this).

## Adding a new app

### A: a published image

1. `make new-stack NAME=myapp IMAGE=vendor/myapp:1.2.3 PORT=8080` (a pinned tag, never `:latest`). It creates
   `stacks/myapp/compose.yml` and `roles/stacks/templates/myapp.env.j2`.
2. Check the compose file: data folder, ports, environment.
3. Secrets: `make secret NAME=myapp_db_password`, then `DB_PASSWORD={{ myapp_db_password }}` in the `.env.j2` and
   `DB_PASSWORD: ${DB_PASSWORD}` in the compose file.
4. Add `myapp` to `stacks_enabled`.
5. `make homelab-lint`, `make homelab-check`, then deploy with `--tags apps`.
   Now it answers at `https://myapp.<local domain>` on the LAN.
6. Public only if needed: add its hostname and DNS record in `terraform/cloudflare/tunnel.tf` (copy `apex_api`),
   `make cf-plan`, `make cf-apply`.
7. Let the security-reviewer agent check the diff, then commit and push (this repo is public).

### B: your own private repo (like APEX)

Everything from A, plus:

1. `make new-deploy-key NAME=myapp_deploy_key COMMENT=homelab-apps-myapp`: the private key goes into SOPS, the
   public key is printed. Add it in GitHub → the repo → Settings → Deploy keys, without write access.
2. In `docker_hosts.yml`: `myapp_repo: git@github.com:<owner>/myapp.git` and `myapp_version: <commit hash>`.
3. Copy `roles/stacks/tasks/config/apex.yml` to `config/myapp.yml` and rename `apex` to `myapp` in it.
4. In the compose file: `build: ./src` (where the Dockerfile is) instead of `image:`, plus
   `image: myapp:${MYAPP_VERSION}` and `pull_policy: never`.

### Data that must survive

Give the app its own ZFS dataset, as `tank/apex` is set up: add `tank/myapp` to `zfs_datasets_list` and
`sanoid_templates` in `group_vars/proxmox.yml`, and to the VM's `docker_host_virtiofs_mounts`. It then appears as
`/srv/myapp` on the VM, with snapshots and backups.

## The three tools, and what Make has to do with them

| Tool | Job | Talks to | Remembers what it did? |
| --- | --- | --- | --- |
| **Terraform** | creates things that live *outside* the machines: Proxmox VMs/LXCs (`terraform/proxmox`), Cloudflare tunnel routes and DNS records (`terraform/cloudflare`) | the Proxmox API, the Cloudflare API | yes: a **state** file (below) |
| **Ansible** | sets up *inside* the machines: packages, users, ZFS datasets, Docker, the stacks | each host over SSH | no: it looks at the host every run |
| **SOPS + age** | keeps secrets encrypted in git and decrypts them in memory | — | — |

**Make** does nothing by itself. `make <target>` runs the commands written under that target in
`Makefile`, so you do not have to type them. `make help` (or just `make`) lists the targets. When in
doubt what a target does, open `Makefile`; every target is a few lines.

## Every make target, and what really runs

| `make …` | Really runs | What it does |
| --- | --- | --- |
| `homelab-check` | `ansible-playbook -i inventories/homelab homelab.yml --check --diff` | dry run of everything: shows what would change, changes nothing |
| `homelab` | the same without `--check --diff` | applies everything to every host |
| *(no target)* | `… homelab.yml --tags apps` | only the apps VM (the stacks); add `--check --diff` for its dry run |
| `homelab-lint` | syntax check, ansible-lint, `terraform fmt`/`validate` for both roots, secrets check | run before committing; CI runs the same |
| `tf-plan` | `terraform plan -out=tfplan.tfplan` in `terraform/proxmox`, with the Proxmox token from `secrets.sops.env` | shows what Terraform would change in Proxmox and saves that plan |
| `tf-apply` | `terraform apply tfplan.tfplan`, then `tfstate.sh backup` | does exactly the saved plan, then updates the encrypted state copy |
| `cf-plan` | `terraform init` + `terraform plan -out=tfplan.tfplan` in `terraform/cloudflare`, via `scripts/homelab/cf-terraform.sh` | the same for Cloudflare routes and DNS |
| `cf-apply` | `terraform apply tfplan.tfplan`, `tfstate.sh backup cloudflare`, deletes the plan file | does the saved Cloudflare plan, updates the encrypted state copy |
| `tf-restore-state` / `cf-restore-state` | `tfstate.sh restore [cloudflare]` | decrypts the state copy from git (new machine or fresh clone) |
| `secret NAME=x` | `scripts/homelab/new-secret.sh` | random password into SOPS, never printed |
| `set-secret NAME=x` | `scripts/homelab/set-secret.sh` | a value you have (API key) into SOPS, hidden prompt |
| `new-deploy-key NAME=x COMMENT=y` | `scripts/homelab/new-deploy-key.sh` | SSH deploy key into SOPS, prints the public half |
| `new-stack NAME=… IMAGE=… PORT=…` | `scripts/homelab/new-stack.sh` | scaffolds `stacks/<name>/compose.yml` and its `.env.j2` |
| `ssh-config` | `scripts/homelab/ssh-config.sh --windows` | SSH host entries (`ssh apps`, …) for WSL and Windows from the inventory |

**plan, then apply.** Terraform never changes anything on `plan`; it compares the code with the state and
the real world and prints `+` (create), `~` (change), `-` (destroy). `apply tfplan.tfplan` then does
*exactly* that saved plan, nothing else. Read the plan every time; a `-` on something you did not mean to
touch is the moment to stop.

## Ansible in a little more detail

- **Inventory** (`inventories/homelab/hosts.yml`): the hosts and their groups (`proxmox`, `docker_hosts`,
  `adguard`, `wireguard`). **group_vars/** hold the settings per group, e.g. `docker_hosts.yml` has
  `stacks_enabled` and `apex_version`.
- **Playbook** (`homelab.yml`): one *play* per group, each a list of **roles** (`roles/<name>/tasks/`).
  Every play has a **tag**: `proxmox`, `apps`, `adguard`, `wireguard`. `--tags apps` runs only the apps
  VM's play; without tags everything runs.
- **Idempotent:** a task checks first and changes only what differs, so running it twice changes nothing
  the second time. "ok" means already right, "changed" means it fixed something.
- `--check --diff` shows the would-be changes. Some tasks cannot be predicted in a dry run (e.g. a Docker
  build), so a real run can still show a few more changes.

## Terraform state: the one thing to understand

Terraform keeps a **state** file (`terraform/<root>/terraform.tfstate`): its list of what it created and
the IDs of those things. Without it, Terraform thinks nothing exists yet and tries to create everything
again, which fails with "already exists" (exactly what happened on 2026-10-19, on a fresh WSL clone).

- The state contains IDs and the domain, so it is **not** in git in plain text (`.gitignore`).
- Git holds an **encrypted copy**: `terraform.tfstate.sops`. `tf-apply`/`cf-apply` update it
  automatically; **commit it** after every apply.
- On a new machine or a fresh clone, **restore first**: `make cf-restore-state` (and `make tf-restore-state`
  for Proxmox), then plan.
- If a run left a wrong state behind, move it away (`mv terraform/cloudflare/terraform.tfstate /tmp/`) and
  restore again; `restore` refuses to overwrite a state that differs, on purpose.
- Only one machine should apply at a time, and always from the latest `git pull`.

## How we use Cloudflare

The domain's DNS is at Cloudflare. We use it for three things:

1. **Public access through the Cloudflare Tunnel.** The `cloudflared` stack (`stacks/cloudflared`) runs
   on the apps VM and opens an *outgoing* connection to Cloudflare. Visitors connect to Cloudflare, and
   Cloudflare passes the request down that connection. So there is **no open port** on the router, and
   your home IP is not public. TLS (https) ends at Cloudflare; `cloudflared` forwards to
   `http://127.0.0.1:<port>` on the VM, which is why public services bind to `127.0.0.1` only.
2. **Public DNS names.** Each public hostname is a `CNAME` to `<tunnel-id>.cfargotunnel.com`, proxied
   (orange cloud).
3. **Certificates for LAN names.** Traefik gets a wildcard certificate for `*.home.<domain>` from Let's
   Encrypt by proving domain ownership through a DNS record (DNS-01). It writes that record with
   `cloudflare_dns_api_token`. LAN names themselves come from AdGuard (`*.home.<domain>` → apps VM), not
   from public DNS.

**Three Cloudflare credentials, all in SOPS:**

| Secret | Used by | Allowed to |
| --- | --- | --- |
| `cloudflared_tunnel_token` | the `cloudflared` container | run this one tunnel (it also contains the account and tunnel IDs, which `cf-terraform.sh` reads) |
| `cloudflare_terraform_api_token` | `make cf-plan` / `cf-apply` | edit the tunnel's routes, edit DNS in this zone |
| `cloudflare_dns_api_token` | Traefik | edit DNS (for the certificate challenge) |

### Where the public routes are

All in **`terraform/cloudflare/tunnel.tf`**:

- `cloudflare_zero_trust_tunnel_cloudflared_config.homelab`: the tunnel's **whole** list of routes
  (`ingress`). Each entry is `hostname` (+ optional `path` regex) → `service`. They are checked **top to
  bottom, first match wins**, and the last entry is the catch-all `http_status:404`. That is how the
  APEX admin APIs are blocked: a 404 rule for those paths comes *before* the rule that sends `^/api/` to
  PocketBase.
- `cloudflare_dns_record.<name>`: one per public hostname (the `CNAME` above).
- Because this file owns the whole route list, a route added by hand in the Cloudflare dashboard is
  **removed** on the next `cf-apply`. Always change routes here.

`scripts/homelab/cf-terraform.sh` is what `cf-plan`/`cf-apply` call: it decrypts the Terraform token, the
account/tunnel IDs and the domain from SOPS into environment variables (never to disk) and runs
`terraform` in `terraform/cloudflare`. That is why the public repo shows neither the domain nor the IDs.

Today's public routes:

| Hostname | Path | Goes to |
| --- | --- | --- |
| `apex-api.<domain>` | `^/api/collections/(_superusers…)/`, admin APIs | 404 (blocked) |
| `apex-api.<domain>` | `^/api/` | PocketBase, `127.0.0.1:8090` |
| `apex.<domain>` | everything | APEX website + PWA, `127.0.0.1:8091` |
| anything else | | 404 |

### Adding a public route

1. The service listens on `127.0.0.1:<port>` on the apps VM (`ports: ["127.0.0.1:<port>:<container port>"]`
   in its compose file). Never an admin UI.
2. In `tunnel.tf`: a `local` for the hostname, an ingress entry **before** the final 404, and a
   `cloudflare_dns_record` (copy `apex_web`).
3. Deploy the stack first (`--tags apps`), so the route has something to answer.
4. `make cf-plan`: expect only your additions (`+ dns record`, `~ tunnel config`). Then `make cf-apply`.
5. Commit the code *and* `terraform/cloudflare/terraform.tfstate.sops`, push.
6. Check from outside: `curl -I https://<hostname>/`.

If `cf-plan` wants to **create** records that already exist (e.g. `apex_api`), the state is missing: stop,
and restore it (above). If the hostname already has a record made by hand in the dashboard, delete that
record there first.

## CI and CD

- CI: `.github/workflows/lint.yml` checks syntax, lint, that secrets are encrypted, and Terraform on every push.
- CD is manual on purpose: deploying needs the age key and SSH access, which only your PC has. GitHub has neither.

## Cheat sheet

| I want to… | Command |
| --- | --- |
| see what would change | `make homelab-check` |
| deploy only the apps VM | `ANSIBLE_CONFIG=ansible.cfg ansible-playbook -i inventories/homelab homelab.yml --tags apps` |
| deploy everything | `make homelab` |
| store a random password | `make secret NAME=x` |
| store a key I already have | `make set-secret NAME=x` |
| change what is public | `make cf-plan`, then `make cf-apply` |
| add an app | `make new-stack NAME=… IMAGE=… PORT=…` |
| start on a new machine or fresh clone | `make cf-restore-state` and `make tf-restore-state` |
| change Proxmox VMs/LXCs | `make tf-plan`, then `make tf-apply` |
| after any `*-apply` | commit `terraform/*/terraform.tfstate.sops` |
| check everything before a commit | `make homelab-lint` |
