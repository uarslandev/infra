terraform {
  required_version = ">= 1.9"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.26.0"
    }
  }
}

# Auth comes from the environment, never from files in git: scripts/homelab/cf-terraform.sh exports
# CLOUDFLARE_API_TOKEN (cloudflare_terraform_api_token: Account > Cloudflare Tunnel: Edit,
# Zone > DNS: Edit + Zone: Read, one zone) and the TF_VAR_* values below from secrets/homelab.sops.yml.
provider "cloudflare" {}
