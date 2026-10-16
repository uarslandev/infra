# All values come from secrets/homelab.sops.yml via scripts/homelab/cf-terraform.sh, so the domain and the
# account/tunnel IDs never appear in the public repo. Sensitive: plans show them as (sensitive).

variable "account_id" {
  description = "Cloudflare account ID (from the tunnel token)."
  type        = string
  sensitive   = true
}

variable "tunnel_id" {
  description = "ID of the existing, dashboard-created tunnel that cloudflared runs (from the tunnel token)."
  type        = string
  sensitive   = true
}

variable "zone_name" {
  description = "The public domain (derived from jellyfin_published_url, like homelab_public_domain in Ansible)."
  type        = string
  sensitive   = true
}
