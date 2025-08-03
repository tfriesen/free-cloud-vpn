output "instance_id" {
  value = oci_core_instance.free_tier_vm.id
}

output "public_ip" {
  value = oci_core_instance.free_tier_vm.public_ip
}

output "vm_config" {
  value = module.vm_config
}
