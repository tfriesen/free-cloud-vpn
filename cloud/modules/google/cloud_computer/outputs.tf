output "instance_name" {
  value = google_compute_instance.free_tier_vm.name
}

output "generated_ssh_public_key" {
  value = var.ssh_keys != "" ? null : tls_private_key.generated_key[0].public_key_openssh
}

output "generated_ssh_private_key" {
  value     = var.ssh_keys != "" ? null : tls_private_key.generated_key[0].private_key_openssh
  sensitive = true
}

output "vm_ip_address" {
  value       = google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip
  description = "The public IP address of the VM"
}

output "vm_fqdn" {
  value       = format("%s.bc.googleusercontent.com", join(".", reverse(split(".", google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip))))
  description = "FQDN for the VM based on its IPv4 address"
}

output "dns_tunnel_password" {
  description = "The password for the DNS tunnel (only if enabled and auto-generated)"
  value       = var.enable_dns_tunnel && var.dns_tunnel_password == "" ? local.effective_dns_password : null
  sensitive   = true
}

output "dns_tunnel_domain" {
  description = "The domain configured for the DNS tunnel (only if enabled)"
  value       = var.enable_dns_tunnel ? var.dns_tunnel_domain : null
}

output "https_proxy_password" {
  value       = local.effective_proxy_password
  sensitive   = true
  description = "The password for the HTTPS proxy"
}

output "https_proxy_domain" {
  value       = var.https_proxy_domain != "" ? var.https_proxy_domain : "proxy.local"
  description = "The domain name configured for the HTTPS proxy"
}

output "https_proxy_cert" {
  value       = var.https_proxy_domain != "" ? null : tls_self_signed_cert.proxy_cert[0].cert_pem
  description = "The self-signed certificate used by the HTTPS proxy (only if no domain provided)"
}
