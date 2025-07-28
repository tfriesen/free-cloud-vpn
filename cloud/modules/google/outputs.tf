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

output "dns_tunnel_password" {
  description = "The password for the DNS tunnel (only if enabled and auto-generated)"
  value       = module.cloud_computer.dns_tunnel_password
  sensitive   = true
}

output "https_proxy_cert" {
  value       = module.cloud_computer.https_proxy_cert
  description = "The self-signed certificate used by the HTTPS proxy (only if no domain provided)"
}

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value       = module.cloud_computer.wireguard
}

output "ipsec_vpn" {
  description = "IPSec/L2TP VPN configuration and status"
  value       = module.cloud_computer.ipsec_vpn
}

output "ipsec_vpn_secrets" {
  description = "IPSec/L2TP VPN sensitive configuration values"
  value       = module.cloud_computer.ipsec_vpn_secrets
  sensitive   = true
}
