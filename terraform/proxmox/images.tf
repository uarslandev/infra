# Pinned, checksum-verified base images. Bump version + checksum together.

locals {
  ubuntu_cloud_release = "20260927"
}

resource "proxmox_download_file" "ubuntu_cloud" {
  node_name          = var.node_name
  datastore_id       = "local"
  content_type       = "import"
  url                = "https://cloud-images.ubuntu.com/releases/resolute/release-${local.ubuntu_cloud_release}/ubuntu-26.04-server-cloudimg-amd64.img"
  file_name          = "ubuntu-26.04-server-cloudimg-amd64-${local.ubuntu_cloud_release}.qcow2"
  checksum           = "8800651811af9a85465ad1d552add729947bb16488dddb4a9b5305a3d97332b2"
  checksum_algorithm = "sha256"
}

resource "proxmox_download_file" "ubuntu_lxc" {
  node_name           = var.node_name
  datastore_id        = "local"
  content_type        = "vztmpl"
  url                 = "http://download.proxmox.com/images/system/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
  checksum            = "d5607f124d01f8ddfebd8e7da34c0022fb2a464e1662ee1e39a13f5ed1bae08a7364c486247fbd9f69f26c710729884ee5047aadb89f33a40066cd5f0d9def88"
  checksum_algorithm  = "sha512"
  overwrite_unmanaged = true
}
