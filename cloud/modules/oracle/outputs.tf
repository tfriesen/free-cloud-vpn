# Oracle Cloud-specific outputs
output "instance_id" {
  value = module.cloud_computer.instance_id
}

output "vm_ip_address" {
  value       = module.cloud_computer.public_ip
  description = "The public IP address of the VM"
}

output "vm_ipv6_address" {
  value       = module.cloud_computer.public_ipv6
  description = "The public IPv6 address of the VM (if enabled)"
}

output "vm_fqdn" {
  value       = module.cloud_computer.public_ip
  description = "FQDN for the VM (Oracle doesn't provide automatic FQDN like Google)"
}

# Pass-through outputs from vm_config module
output "generated_ssh_public_key" {
  value = module.cloud_computer.vm_config.generated_ssh_public_key
}

output "generated_ssh_private_key" {
  value     = module.cloud_computer.vm_config.generated_ssh_private_key
  sensitive = true
}

output "pingtunnel_key" {
  description = "The key for pingtunnel authentication (only if enabled and auto-generated)"
  value       = module.cloud_computer.vm_config.pingtunnel_key
  sensitive   = true
}

output "pingtunnel_aes_key" {
  description = "The AES encryption key for pingtunnel (only if enabled and auto-generated)"
  value       = module.cloud_computer.vm_config.pingtunnel_aes_key
  sensitive   = true
}

output "dns_tunnel_password" {
  description = "The password for the DNS tunnel (only if enabled and auto-generated)"
  value       = module.cloud_computer.vm_config.dns_tunnel_password
  sensitive   = true
}

output "dns_tunnel_domain" {
  description = "The domain configured for the DNS tunnel (only if enabled)"
  value       = module.cloud_computer.vm_config.dns_tunnel_domain
}

output "https_proxy_cert" {
  description = "The self-signed certificate used by the HTTPS proxy (only if no domain provided)"
  value       = module.cloud_computer.vm_config.https_proxy_cert
}

output "https_proxy_password" {
  value       = module.cloud_computer.vm_config.https_proxy_password
  sensitive   = true
  description = "The password for the HTTPS proxy"
}

output "https_proxy_domain" {
  value       = module.cloud_computer.vm_config.https_proxy_domain
  description = "The domain name configured for the HTTPS proxy"
}

output "ipsec_vpn_username" {
  description = "The username for the IPSec VPN"
  value       = module.cloud_computer.vm_config.ipsec_vpn_username
}

output "ipsec_vpn" {
  description = "IPSec/IKEv2 VPN configuration and status"
  value = {
    enabled        = var.ipsec_vpn_config.enable
    username       = module.cloud_computer.vm_config.ipsec_vpn_username
    client_ip_pool = var.ipsec_vpn_config.enable ? var.ipsec_vpn_config.client_ip_pool : null
    server_ip      = var.ipsec_vpn_config.enable ? module.cloud_computer.public_ip : null
  }
}

output "ipsec_vpn_secrets" {
  description = "IPSec/IKEv2 VPN sensitive configuration values (PSK-based)"
  value = {
    password = module.cloud_computer.vm_config.ipsec_vpn_password
    psk      = module.cloud_computer.vm_config.ipsec_psk
  }
  sensitive = true
}

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value = {
    enabled = var.wireguard_config.enable
    public_key = coalesce(
      module.cloud_computer.vm_config.wireguard_public_key,
    "There was an error retrieving the public key. It can be retrieved by logging into the VM in the file at '/etc/wireguard/public.key'. Sometimes re-running 'plan' or 'apply' can resolve this.")
    port          = var.wireguard_config.enable ? var.wireguard_config.port : null
    server_ip     = var.wireguard_config.enable ? module.cloud_computer.public_ip : null
    client_config = module.cloud_computer.vm_config.wireguard_client_config
  }
}
