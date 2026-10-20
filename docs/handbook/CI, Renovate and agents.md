---
tags: [infra, ci]
---
# CI, Renovate and agents

Back to [[Home]].

## CI (GitHub Actions, `.github/workflows/`)

| Workflow | When | Checks |
| --- | --- | --- |
| `lint.yml` — homelab | every push and PR to `main` | pinned Ansible + collections, **secrets are encrypted**, playbook syntax, `ansible-lint --profile production`, Terraform `fmt` + `validate` |
| `dotfiles.yml` — dev environment | every push and PR | Ansible syntax + lint of `dotfiles/`, ShellCheck on the scripts |
| `build_arch_iso.yml` | by hand only | builds an Arch Linux ISO with the LTS kernel and ZFS, publishes it |

`make homelab-lint` runs the same homelab checks locally; run it before committing.

**There is no CD on purpose.** Deploying needs your age key and SSH access, which only your PC has.
GitHub has neither, so a leaked GitHub token cannot change your servers.

## Renovate (`renovate.json`)

A bot that opens pull requests when a pinned version has an update: container images in `stacks/`,
Terraform providers, Ansible collections, GitHub Actions. Saturday mornings, with release notes.

- **Major versions** wait for your approval on the Dependency Dashboard (database migrations, breaking
  changes).
- Grouped: Immich server + machine learning; Nextcloud app + cron; all Terraform providers; all
  collections.
- Not touched: Immich's Postgres and Valkey (Immich's release notes decide those).
- GitHub Actions updates merge automatically.

Flow: PR → CI green → you merge → `git pull` → `--tags apps` (or the matching apply).

## Agents (`.claude/agents/`)

AI helpers for Claude Code in this repo, each with a narrow job:

| Agent | Job |
| --- | --- |
| `security-reviewer` | before every commit: leaked secrets, internal details, exposed services, unsafe defaults (the repo is public) |
| `devops-engineer` | designs or reviews Terraform, Ansible, Compose, ZFS changes; smallest safe change + how to verify |
| `qa-engineer` | turns a request into acceptance criteria and checks a change really meets them |

`CLAUDE.md` holds the rules any assistant must follow here (read-only first, explicit OK for anything
destructive, Immich/Nextcloud data must never be lost, nothing secret in chat or git).
