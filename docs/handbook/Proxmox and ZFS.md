---
tags: [infra, homelab, storage]
---
# Proxmox and ZFS

Back to [[Home]]. The physical server, and where all the data lives.

## The host

- **Proxmox VE** on a small boot SSD that holds only the operating system. Hardware details:
  [[homelab/inventory|Inventory]].
- Set up by Ansible (`--tags proxmox`): packages, the `wireguard` kernel module, SMART monitoring
  (`proxmox_host`), SSH keys (`ssh_access`), host metrics (`node_exporter`).
- Its guests (VM 110 `apps`, LXC 120 `adguard`, LXC 121 `wireguard`) are created by Terraform
  (`terraform/proxmox`); their disks live on `tank`, never on the boot SSD.

## The pool `tank`

A ZFS **mirror** of two 2 TB disks: every block is on both, so one disk can die without data loss.
It is the only irreplaceable thing in the homelab.

| Dataset | Holds | Snapshot policy |
| --- | --- | --- |
| `tank/immich` | photo library + its Postgres | critical |
| `tank/nextcloud` | files, MariaDB | critical |
| `tank/appdata` | small app state: Traefik certificate, Prometheus, Alertmanager, Grafana | standard |
| `tank/apex` | APEX's PocketBase database | standard |
| `tank/syncthing` | config + synced folders | standard |
| `tank/jellyfin` | media, config, cache | media |
| `tank/legacy` | pre-rebuild DB dumps, kept (with a ZFS hold) until real backups exist | — |

Datasets are listed in `inventories/homelab/group_vars/proxmox.yml` (`zfs_datasets_list`); the
`zfs_datasets` role creates missing ones and **never** destroys any.

## How data reaches the apps (virtiofs)

```
Proxmox host  /tank/immich ──virtiofs share "immich"──►  apps VM  /srv/immich ──bind mount──► container
```

1. Terraform (`terraform/proxmox/terraform.tfvars`, `virtiofs_shares`) shares the folder with the VM.
2. Ansible (`docker_host`, `docker_host_virtiofs_mounts`) mounts it at `/srv/<name>` inside the VM.
3. Each `compose.yml` mounts `/srv/<name>/...` into its containers.

That is why the VM can be thrown away and rebuilt: nothing in it is the only copy.
Adding a dataset: [[Runbooks#New ZFS dataset]].

## Snapshots

**sanoid** (role `sanoid`, timer on the host) takes and prunes snapshots per policy
(`sanoid_templates` in `proxmox.yml`):

| Policy | Hourly | Daily | Weekly | Monthly |
| --- | --- | --- | --- | --- |
| critical | 24 | 14 | 8 | 6 |
| standard | 0 | 7 | 4 | 3 |
| media | 0 | 3 | 2 | 0 |

A snapshot is a read-only, instant picture of a dataset. Every one is browsable at
`/tank/<dataset>/.zfs/snapshot/<name>/`, so restoring one file is a copy → [[Runbooks#Restore a file]].

> [!warning] Snapshots are not backups
> They live on the same disks. Fire, theft, a pool failure or a `zfs destroy` takes them too.
> A copy outside the pool (Proxmox Backup Server on a USB disk) is the top item in [[homelab/TODO|TODO]].

> [!danger] Never without an explicit OK
> `zfs destroy`, `zfs rollback` (throws away everything newer), `zfs release` on the `keep` holds,
> any `zpool` change. Immich and Nextcloud data must never be lost.
