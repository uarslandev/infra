# Small infrastructure services as unprivileged Ubuntu LXCs (AdGuard Home, WireGuard).
# Root login is key-only; Ansible configures the services.

resource "proxmox_virtual_environment_container" "lxc" {
  for_each = var.containers

  description   = "${each.key}. Managed by Terraform."
  tags          = ["terraform", each.key]
  node_name     = var.node_name
  vm_id         = each.value.vm_id
  unprivileged  = true
  start_on_boot = true
  started       = true

  features {
    nesting = true # required by systemd in recent Ubuntu releases
  }

  operating_system {
    template_file_id = proxmox_download_file.ubuntu_lxc.id
    type             = "ubuntu"
  }

  cpu {
    cores = each.value.cores
  }

  memory {
    dedicated = each.value.memory_mb
    swap      = 0
  }

  disk {
    datastore_id = var.vm_datastore
    size         = each.value.disk_gb
  }

  network_interface {
    name   = "eth0"
    bridge = var.network.bridge
  }

  initialization {
    hostname = each.key

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network.cidr_suffix}"
        gateway = var.network.gateway
      }
    }

    dns {
      servers = var.network.dns
    }

    user_account {
      keys = [local.ssh_public_key]
    }
  }
}
