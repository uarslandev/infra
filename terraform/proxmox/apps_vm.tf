# The "apps" VM: Docker host for every application stack. Holds no data itself;
# all persistent data comes from ZFS datasets via virtiofs, so this VM can be recreated at any time.

resource "proxmox_hardware_mapping_dir" "share" {
  for_each = var.virtiofs_shares

  name    = each.key
  comment = "Managed by Terraform"
  map = [{
    node = var.node_name
    path = each.value
  }]
}

resource "proxmox_virtual_environment_file" "apps_user_data" {
  node_name    = var.node_name
  datastore_id = "local"
  content_type = "snippets"

  source_raw {
    file_name = "apps-user-data.yaml"
    data = templatefile("${path.module}/templates/user-data.yaml.tftpl", {
      hostname   = "apps"
      admin_user = var.admin_user
      ssh_key    = local.ssh_public_key
    })
  }
}

resource "proxmox_virtual_environment_vm" "apps" {
  name        = "apps"
  description = "Docker host for application stacks. Managed by Terraform."
  tags        = ["terraform", "docker"]
  node_name   = var.node_name
  vm_id       = var.apps_vm.vm_id

  machine       = "q35"
  scsi_hardware = "virtio-scsi-single"
  on_boot       = true
  started       = true

  agent {
    enabled = true
  }

  cpu {
    cores = var.apps_vm.cores
    type  = "host"
  }

  memory {
    dedicated = var.apps_vm.memory_mb
  }

  disk {
    datastore_id = var.vm_datastore
    import_from  = proxmox_download_file.ubuntu_cloud.id
    interface    = "scsi0"
    size         = var.apps_vm.disk_gb
    iothread     = true
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge = var.network.bridge
  }

  dynamic "virtiofs" {
    for_each = proxmox_hardware_mapping_dir.share
    content {
      mapping = virtiofs.value.name
    }
  }

  initialization {
    datastore_id      = var.vm_datastore
    user_data_file_id = proxmox_virtual_environment_file.apps_user_data.id

    ip_config {
      ipv4 {
        address = "${var.apps_vm.ip}/${var.network.cidr_suffix}"
        gateway = var.network.gateway
      }
    }

    dns {
      servers = var.network.dns
    }
  }

  operating_system {
    type = "l26"
  }

  serial_device {}

  vga {
    type = "serial0"
  }
}
