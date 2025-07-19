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

output "vm_instance_name" {
  value = module.cloud_computer.instance_name
}

output "vm_fqdn" {
  value = module.cloud_computer.vm_fqdn
}

output "https_proxy_cert" {
  value       = module.cloud_computer.https_proxy_cert
  description = "The self-signed certificate used by the HTTPS proxy (only if no domain provided)"
}
