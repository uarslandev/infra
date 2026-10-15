locals {
  # Only "<type> <base64>" of the public key: a multi-line key comment would break cloud-init YAML.
  ssh_public_key = regex("^(ssh-[a-z0-9-]+ [A-Za-z0-9+/=]+)", file(pathexpand(var.ssh_public_key_path)))[0]
}
