terraform {
  required_version = ">= 1.9"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.116.1"
    }
  }
}

# Auth comes from the environment (never from files in git):
#   PROXMOX_VE_API_TOKEN  -> decrypted on the fly from secrets.sops.env via `sops exec-env`
provider "proxmox" {
  endpoint = var.proxmox_endpoint
  insecure = true # self-signed PVE certificate on the LAN

  # Used for uploading the cloud-init snippet (the API cannot upload snippets).
  ssh {
    username    = "root"
    private_key = file(pathexpand(var.ssh_private_key_path))
  }
}
