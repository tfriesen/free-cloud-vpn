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

output "https_proxy" {
  description = "Non-sensitive HTTPS proxy configuration"
  value       = module.vm_config.https_proxy
}

output "https_proxy_secrets" {
  description = "Sensitive HTTPS proxy secrets (password, private key)"
  value       = module.vm_config.https_proxy_secrets
  sensitive   = true
}

output "dns_tunnel_domain" {
  description = "The domain configured for the DNS tunnel (only if enabled)"
  value       = module.vm_config.dns_tunnel_domain
}

output "vm_config" {
  value = module.vm_config
}
