# How deploys work

A walkthrough for the owner: what happens when you deploy, where secrets live, and how to add a new app.
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
