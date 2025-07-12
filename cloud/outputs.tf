output "generated_aes_key" {
  value     = length(module.aws) > 0 ? module.aws[0].generated_aes_key : null
  sensitive = true
}

output "generated_ssh_public_key" {
  value = length(module.google) > 0 ? module.google[0].generated_ssh_public_key : null
}

output "generated_ssh_private_key" {
  value = length(module.google) > 0 ? module.google[0].generated_ssh_private_key : null
  sensitive = true
}

output "vm_ip_address" {
  value = length(module.google) > 0 ? module.google[0].vm_ip_address : null
}

