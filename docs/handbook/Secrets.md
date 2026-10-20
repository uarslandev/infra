---
tags: [infra, security]
---
# Secrets

Back to [[Home]]. Every password, token and private key is in git, **encrypted**. Nothing secret is
ever in git in plain text, in a chat, in a shell history or in these notes.

## SOPS + age, in plain words

- **age** is the encryption. A key pair:
  - the **public key** is in `.sops.yaml` and can only *encrypt*;
  - the **private key** is `~/.config/sops/age/keys.txt` on your PC (plus KeePass and a printout). Only it
    can *decrypt*. Lose it and every secret is gone; leak it and every secret is exposed.
- **SOPS** encrypts the *values* in a YAML file and leaves the names readable. So a diff shows *which*
  secret changed, never its value.

## The files

| File | Holds | Read by |
| --- | --- | --- |
| `secrets/homelab.sops.yml` | everything for Ansible and the Cloudflare Terraform (DB passwords, tokens, deploy key, WireGuard config, SMTP, …) | Ansible (`community.sops.load_vars`), `cf-terraform.sh` |
| `terraform/proxmox/secrets.sops.env` | the Proxmox API token | `sops exec-env` in `make tf-*` |
| `terraform/*/terraform.tfstate.sops` | the Terraform state, as one opaque blob | `tfstate.sh` → [[Tools#Terraform state]] |

## From git to the app

```
secrets/homelab.sops.yml (encrypted, in git)
   │ Ansible decrypts in memory with your age key (never written to your disk)
   ▼
roles/stacks/templates/<app>.env.j2       e.g.  DB_PASSWORD={{ nextcloud_mysql_password }}
   │ rendered on the server, root-only (0600), no_log
   ▼
/opt/stacks/<app>/.env                    the only plain copy, on the server
   │ Docker Compose fills ${DB_PASSWORD} in compose.yml
   ▼
the container's environment
```

## Commands

```bash
make secret NAME=app_db_password          # random value, never printed
make set-secret NAME=some_api_token       # a value you have: hidden prompt, not in history
sops secrets/homelab.sops.yml             # edit several values in an editor
sops decrypt --extract '["name"]' secrets/homelab.sops.yml   # read one value
make new-deploy-key NAME=x COMMENT=y      # SSH deploy key: private half in, public half printed
```

Never paste a secret into a command line (it lands in the shell history); use `set-secret`.

## Guards

- `scripts/homelab/check-secrets.sh` (in `make homelab-lint` and CI) fails if a secret file is not
  encrypted.
- `.gitignore` excludes `.env`, `keys.txt`, `*.agekey`, decrypted files, Terraform state and plans.
- The `security-reviewer` agent checks every diff before a commit → [[CI, Renovate and agents]].

## A new device, or removing one

A new PC needs the age key (copy from KeePass) or its own key added to `.sops.yaml` plus
`sops updatekeys` on every secret file → [[Runbooks#New device]]. Removing a device: delete its key and
rotate the secrets it could read.
