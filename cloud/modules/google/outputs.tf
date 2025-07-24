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

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value       = module.cloud_computer.wireguard
}

output "vpn_username" {
  value       = module.cloud_computer.vpn_username
  description = "The username for VPN authentication"
}

output "vpn_password" {
  value       = module.cloud_computer.vpn_password
  description = "The auto-generated password for VPN authentication (only shown if auto-generated)"
  sensitive   = true
}

output "ipsec_psk" {
  value       = module.cloud_computer.ipsec_psk
  description = "The auto-generated IPSec pre-shared key (only shown if auto-generated)"
  sensitive   = true
}

output "vpn_client_ip_pool" {
  value       = module.cloud_computer.vpn_client_ip_pool
  description = "The IP address pool used for VPN clients"
}
