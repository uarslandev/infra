variable "proxmox_endpoint" {
  description = "Proxmox API URL, e.g. https://192.168.0.10:8006/"
  type        = string
}

variable "node_name" {
  description = "Proxmox node name."
  type        = string
}

variable "ssh_private_key_path" {
  description = "Local SSH private key used by the provider for snippet uploads (stays on the admin PC)."
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_public_key_path" {
  description = "Public key installed for the admin user in all guests."
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "admin_user" {
  description = "Admin user created in VMs by cloud-init (LXCs use root with key only)."
  type        = string
}

variable "network" {
  description = "LAN settings shared by all guests."
  type = object({
    bridge      = string
    cidr_suffix = number
    gateway     = string
    dns         = list(string)
  })
}

variable "vm_datastore" {
  description = "Storage for guest disks (never the boot SSD)."
  type        = string
  default     = "tank"
}

variable "apps_vm" {
  description = "Docker host for all application stacks."
  type = object({
    vm_id     = number
    ip        = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  })
}

variable "virtiofs_shares" {
  description = "ZFS dataset paths on the host shared into the apps VM via virtiofs (mapping name => host path)."
  type        = map(string)
}

variable "containers" {
  description = "Infrastructure LXCs (unprivileged, Ubuntu)."
  type = map(object({
    vm_id     = number
    ip        = string
    cores     = number
    memory_mb = number
    disk_gb   = number
  }))
}
