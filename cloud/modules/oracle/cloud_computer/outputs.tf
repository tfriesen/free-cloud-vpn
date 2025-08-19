output "instance_id" {
  value = oci_core_instance.free_tier_vm.id
}

output "public_ip" {
  value = oci_core_instance.free_tier_vm.public_ip
}

output "public_ipv6" {
  description = "The primary IPv6 address on the instance's primary VNIC, if IPv6 is enabled"
  value       = try(data.oci_core_vnic.primary[0].ipv6addresses[0], null)
}

output "vm_config" {
  value = module.vm_config
}
