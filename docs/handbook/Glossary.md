---
tags: [infra, reference]
---
# Glossary

Back to [[Home]].

| Word | Meaning |
| --- | --- |
| **age** | the encryption tool behind the secrets; a public key encrypts, your private key decrypts → [[Secrets]] |
| **Ansible** | connects over SSH and makes machines match the repo → [[Tools#Ansible]] |
| **apply** | Terraform carrying out a saved plan |
| **cloud-init** | first-boot setup of the VM (user, SSH key), written by Terraform |
| **cloudflared** | the program that keeps the Cloudflare Tunnel open from home → [[Cloudflare]] |
| **Compose / stack** | one app as a `compose.yml`: which containers, ports, volumes → [[Apps VM and stacks]] |
| **dataset** | a ZFS "folder" with its own settings and snapshots, e.g. `tank/immich` |
| **deploy key** | an SSH key that may only *read* one GitHub repo (APEX) |
| **DNS-01** | proving domain ownership with a DNS record, to get a certificate → [[Networking#Traefik]] |
| **drift** | a server that no longer matches the repo; a second Ansible run with `changed=0` means none |
| **group_vars** | Ansible settings per group of hosts |
| **idempotent** | running it twice changes nothing the second time |
| **ingress** | the tunnel's list of routes, first match wins |
| **inventory** | Ansible's list of machines |
| **LXC** | a light container on Proxmox sharing the host's kernel (AdGuard, WireGuard) |
| **plan** | Terraform's preview: `+` create, `~` change, `-` destroy; changes nothing |
| **playbook / play / role / task** | the run file / one block per host group / a reusable unit / one step |
| **Renovate** | the bot that opens update PRs → [[CI, Renovate and agents]] |
| **sanoid** | takes and prunes ZFS snapshots by policy |
| **snapshot** | a read-only picture of a dataset at one moment; not a backup |
| **SOPS** | encrypts the values in YAML files with age |
| **state** | Terraform's record of what it created → [[Tools#Terraform state]] |
| **tag** (Ansible) | a label to run only part of a playbook, e.g. `--tags apps` |
| **tank** | the ZFS pool, a mirror of two disks: all the data |
| **Terraform** | creates VMs, containers, routes from code → [[Tools#Terraform]] |
| **Traefik** | the LAN reverse proxy: names, HTTPS, routing |
| **tunnel** | the outgoing connection that lets Cloudflare reach home without an open port |
| **virtiofs** | how a folder of the host appears inside the VM |
| **VM** | a full virtual machine (the apps VM) |
| **WireGuard** | the VPN for reaching the homelab from outside |
