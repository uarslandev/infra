# Public routes of the Cloudflare Tunnel. This resource owns the tunnel's WHOLE ingress list: a route added
# in the dashboard is removed on the next apply. Every public hostname needs a route here and a DNS record below.
# Never route an admin UI here (admin access: LAN, WireGuard, SSH tunnel).

data "cloudflare_zone" "main" {
  filter = {
    name = var.zone_name
  }
}

locals {
  apex_api_hostname  = "apex-api.${var.zone_name}"
  apex_web_hostname  = "apex.${var.zone_name}"
  portfolio_hostname = var.zone_name
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "homelab" {
  account_id = var.account_id
  tunnel_id  = var.tunnel_id

  config = {
    ingress = [
      {
        # APEX: superuser (admin) sign-in is API too, but admins use the LAN or an SSH tunnel. Rules match in
        # order, so this blocks it before the API rule below. The collection also answers to its ID.
        hostname = local.apex_api_hostname
        path     = "(?i)^/api/collections/(_superusers|pbc_3142635823)/"
        service  = "http_status:404"
      },
      {
        # APEX: admin-only APIs (settings, backups, logs, crons, collection schema). They need a superuser token anyway;
        # this keeps them off the internet even if such a token leaks. The app only uses .../<collection>/records and auth.
        hostname = local.apex_api_hostname
        path     = "(?i)^/api/((settings|backups|logs|crons)(/|$)|collections/?$|collections/import|collections/[^/]+/?$|collections/[^/]+/truncate)"
        service  = "http_status:404"
      },
      {
        # APEX sync server: only the API. The admin UI (/_/) and everything else falls through to the 404 below.
        hostname = local.apex_api_hostname
        path     = "^/api/"
        service  = "http://127.0.0.1:8090"
      },
      {
        # APEX website and PWA (stacks/apex, service `web`): static files only, nothing to sign in to.
        hostname = local.apex_web_hostname
        service  = "http://127.0.0.1:8091"
      },
      {
        # Portfolio (stacks/portfolio, service `web`): the personal site at the zone root, static files only.
        hostname = local.portfolio_hostname
        service  = "http://127.0.0.1:8092"
      },
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_dns_record" "apex_api" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = local.apex_api_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # automatic (required for proxied records)
  comment = "Managed by Terraform (uarslandev/infra terraform/cloudflare)"
}

resource "cloudflare_dns_record" "apex_web" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = local.apex_web_hostname
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # automatic (required for proxied records)
  comment = "Managed by Terraform (uarslandev/infra terraform/cloudflare)"
}

resource "cloudflare_dns_record" "portfolio" {
  zone_id = data.cloudflare_zone.main.zone_id
  name    = local.portfolio_hostname # the zone root; Cloudflare flattens the proxied CNAME
  type    = "CNAME"
  content = "${var.tunnel_id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # automatic (required for proxied records)
  comment = "Managed by Terraform (uarslandev/infra terraform/cloudflare)"
}
