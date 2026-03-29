output "vm_ips" {
  description = "Map of node name to primary IP address"
  value       = { for name, vm in proxmox_virtual_environment_vm.node : name => try(vm.ipv4_addresses[7][0], "") }
}

output "vms" {
  description = "All VM resources"
  value       = proxmox_virtual_environment_vm.node
}
