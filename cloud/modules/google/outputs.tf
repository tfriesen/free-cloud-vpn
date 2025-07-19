output "generated_ssh_public_key" {
  value = module.cloud_computer.generated_ssh_public_key
}

output "generated_ssh_private_key" {
  value     = module.cloud_computer.generated_ssh_private_key
  sensitive = true
}

output "vm_ip_address" {
  value = module.cloud_computer.vm_ip_address
}

