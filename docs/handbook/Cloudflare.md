---
tags: [infra, homelab, cloudflare, network]
---
# Cloudflare

Back to [[Home]]. The domain's DNS is at Cloudflare, and Cloudflare is the only door from the internet.

## Three uses

1. **Public access through the Cloudflare Tunnel.** The `cloudflared` stack on the apps VM opens an
   *outgoing* connection to Cloudflare. Visitors connect to Cloudflare, which passes their requests down
   that connection. So **no port is open on the router**, and your home IP is not public. HTTPS ends at
   Cloudflare; `cloudflared` forwards to `http://127.0.0.1:<port>` on the VM. That is why public services
   listen on `127.0.0.1` only.
2. **Public DNS names**: each public hostname is a `CNAME` to `<tunnel-id>.cfargotunnel.com`, proxied
   (orange cloud).
3. **Certificates for LAN names**: Traefik proves domain ownership for `*.home.<domain>` with a DNS record
   it writes at Cloudflare → [[Networking#Traefik]].

```
Visitor ──https──► Cloudflare ──tunnel (outgoing from home)──► cloudflared ──http──► 127.0.0.1:<port>
                    (TLS ends here)                                (apps VM)          (one service)
```

## Three credentials, all in SOPS

| Secret | Used by | Allowed to |
| --- | --- | --- |
| `cloudflared_tunnel_token` | the `cloudflared` container | run this one tunnel (also carries the account and tunnel IDs) |
| `cloudflare_terraform_api_token` | `make cf-plan` / `cf-apply` | edit the tunnel's routes, edit DNS in this one zone |
| `cloudflare_dns_api_token` | Traefik | edit DNS (certificate challenge) |

## Where the routes are: `terraform/cloudflare/tunnel.tf`

- `cloudflare_zero_trust_tunnel_cloudflared_config.homelab`: the tunnel's **whole** list of routes
  (`ingress`). Each entry: `hostname` (+ optional `path` regex) → `service`. Checked **top to bottom,
  first match wins**; the last entry is the catch-all `http_status:404`.
- `cloudflare_dns_record.<name>`: one per public hostname.
- Because the file owns the whole list, a route added by hand in the Cloudflare dashboard **disappears**
  on the next `cf-apply`. Always change routes here.

Blocking works by order: for `apex-api`, two 404 rules (superuser sign-in, admin APIs) come *before*
the rule that sends `^/api/` to PocketBase, and everything not matched falls to the final 404.

### Current public routes

| Hostname | Path | Goes to |
| --- | --- | --- |
| `apex-api.<domain>` | superuser sign-in, admin APIs | 404 |
| `apex-api.<domain>` | `^/api/` | PocketBase, `127.0.0.1:8090` |
| `apex.<domain>` | everything | APEX website + PWA, `127.0.0.1:8091` |
| anything else | | 404 |

## How `cf-plan` gets its credentials

`make cf-plan` → `scripts/homelab/cf-terraform.sh`, which decrypts from `secrets/homelab.sops.yml`, in
memory only:
- the Terraform API token → `CLOUDFLARE_API_TOKEN`;
- the account and tunnel IDs (inside the tunnel token) → `TF_VAR_account_id`, `TF_VAR_tunnel_id`;
- the domain (from `jellyfin_published_url`) → `TF_VAR_zone_name`.

Then it runs `terraform` in `terraform/cloudflare`. That is why the public repo shows neither the domain
nor any ID. Plan files contain them in plain text, so `cf-apply` deletes the plan afterwards.

## State

Same as for Proxmox: local state, encrypted copy `terraform/cloudflare/terraform.tfstate.sops` in git,
**restore on a fresh clone** (`make cf-restore-state`), commit the copy after every apply →
[[Tools#Terraform state]].

> [!example] What a missing state looks like (2026-10-19)
> On a fresh WSL clone, `cf-apply` wanted to *create* the existing `apex_api` record and failed with
> "An A, AAAA, or CNAME record with that host already exists". Fix: move the stray state away,
> `make cf-restore-state`, plan again.

## Adding a public route

[[Runbooks#Make something public]]. Afterwards always check from outside that admin paths answer 404.

## Not in Terraform (yet)

Zone settings (SSL/TLS mode, WAF) and the tunnel itself were made in the dashboard; see
[[homelab/TODO|TODO]].
