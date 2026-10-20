---
tags: [infra, homelab, monitoring]
---
# Monitoring and alerts

Back to [[Home]]. The `monitoring` stack on the apps VM watches the whole homelab and e-mails you when
something is wrong.

## The parts

| Part | Job |
| --- | --- |
| **node-exporter** (role `node_exporter`, on every host) | host metrics: CPU, RAM, disks; on Proxmox also ZFS and SMART |
| **cAdvisor** | per-container metrics on the apps VM |
| **blackbox** | probes from outside an app: "does it answer?" (`monitoring_http_probes` in `docker_hosts.yml`, including the public APEX API through the tunnel) |
| **pve-exporter** | Proxmox itself, through a read-only API token |
| **Prometheus** | collects all of the above every few seconds and evaluates the alert rules |
| **Alertmanager** | turns firing alerts into e-mails (Gmail SMTP with an app password, from SOPS) |
| **Grafana** | dashboards; `https://grafana.home.<domain>`, user `admin`, password in SOPS (`grafana_admin_password`) |

Config files in `stacks/monitoring/config/` are rendered by Ansible
(`roles/stacks/tasks/config/monitoring.yml`). Grafana's dashboards come from grafana.com at pinned
revisions (`monitoring_dashboards`).

## The alerts

Rules: `stacks/monitoring/config/prometheus/rules/homelab.yml`.

| Alert | Means |
| --- | --- |
| `TargetDown` | an exporter stopped answering |
| `ServiceProbeFailed` | an app's health check failed |
| `ZfsPoolNotOnline` | the pool is degraded: a disk failed |
| `SmartUnhealthy`, `SmartReallocatedSectorsIncreased` | a disk is dying |
| `FilesystemAlmostFull` | a disk or dataset is filling up |
| `HostMemoryLow` | RAM is running out |
| `HostOutOfSync` | a clock is off |
| `CertificateExpiresSoon` | a certificate is not being renewed |

> [!tip] Testing an alert
> Stop a container (`sudo docker stop jellyfin`): `ServiceProbeFailed` should arrive by mail within a few
> minutes. Start it again afterwards.
