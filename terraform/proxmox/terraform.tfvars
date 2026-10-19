# Non-secret settings only (private LAN addresses). Secrets: secrets.sops.env.
proxmox_endpoint = "https://192.168.0.123:8006/"
node_name        = "pve-guide"
admin_user       = "umut"

network = {
  bridge      = "vmbr0"
  cidr_suffix = 24
  gateway     = "192.168.0.1"
  dns         = ["192.168.0.1"] # router, so infra does not depend on AdGuard
}

apps_vm = {
  vm_id     = 110
  ip        = "192.168.0.85" # same IP as the old servarr VM: tunnel + LAN clients keep working
  cores     = 8
  memory_mb = 24576
  disk_gb   = 64
}

virtiofs_shares = {
  immich    = "/tank/immich"
  nextcloud = "/tank/nextcloud"
  jellyfin  = "/tank/jellyfin"
  syncthing = "/tank/syncthing"
  appdata   = "/tank/appdata"
  apex      = "/tank/apex"
  forge     = "/tank/forge"
}

containers = {
  adguard = {
    vm_id     = 120
    ip        = "192.168.0.162"
    cores     = 1
    memory_mb = 512
    disk_gb   = 4
  }
  wireguard = {
    vm_id     = 121
    ip        = "192.168.0.93"
    cores     = 1
    memory_mb = 512
    disk_gb   = 4
  }
}
