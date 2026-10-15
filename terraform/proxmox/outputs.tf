output "apps_vm_ip" {
  value = var.apps_vm.ip
}

output "containers" {
  value = { for k, v in var.containers : k => v.ip }
}
