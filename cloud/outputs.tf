output "generated_aes_key" {
  value     = module.aws.generated_aes_key
  sensitive = true
}

output "generated_ssh_public_key" {
  value = module.google.generated_ssh_public_key
}

output "generated_ssh_private_key" {
  value = module.google.generated_ssh_private_key
  sensitive = true
}

output "vm_ip_address" {
  value = module.google.vm_ip_address
}

output "vm_dns_name" {
  value = module.google.vm_dns_name
}
