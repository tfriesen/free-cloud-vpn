# Google Cloud-specific outputs
output "instance_name" {
  value = google_compute_instance.free_tier_vm.name
}

output "vm_ip_address" {
  value       = google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip
  description = "The public IP address of the VM"
}

output "vm_fqdn" {
  value       = format("%s.bc.googleusercontent.com", join(".", reverse(split(".", google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip))))
  description = "FQDN for the VM based on its IPv4 address"
}

# Pass-through outputs from vm_config module
output "generated_ssh_public_key" {
  value = module.vm_config.generated_ssh_public_key
}

output "generated_ssh_private_key" {
  value     = module.vm_config.generated_ssh_private_key
  sensitive = true
}

output "pingtunnel_key" {
  description = "The key for pingtunnel authentication (only if enabled and auto-generated)"
  value       = module.vm_config.pingtunnel_key
  sensitive   = true
}

output "pingtunnel_aes_key" {
  description = "The AES encryption key for pingtunnel (only if enabled and auto-generated)"
  value       = module.vm_config.pingtunnel_aes_key
  sensitive   = true
}

output "dns_tunnel_password" {
  description = "The password for the DNS tunnel (only if enabled and auto-generated)"
  value       = module.vm_config.dns_tunnel_password
  sensitive   = true
}

output "dns_tunnel_domain" {
  description = "The domain configured for the DNS tunnel (only if enabled)"
  value       = module.vm_config.dns_tunnel_domain
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

output "ipsec_vpn_username" {
  description = "The username for the IPSec VPN"
  value       = module.vm_config.ipsec_vpn_username
}

output "ipsec_vpn" {
  description = "IPSec/IKEv2 VPN configuration and status"
  value = {
    enabled        = var.ipsec_vpn_config.enable
    username       = module.vm_config.ipsec_vpn_username
    client_ip_pool = var.ipsec_vpn_config.enable ? var.ipsec_vpn_config.client_ip_pool : null
    server_ip      = var.ipsec_vpn_config.enable ? google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip : null
  }
}

output "ipsec_vpn_secrets" {
  description = "IPSec/IKEv2 VPN sensitive configuration values (PSK-based)"
  value = {
    password = module.vm_config.ipsec_vpn_password
    psk      = module.vm_config.ipsec_psk
  }
  sensitive = true
}

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value = {
    enabled = var.wireguard_config.enable
    public_key = coalesce(
      var.wireguard_config.enable ? data.google_compute_instance_guest_attributes.wg_public_key[0].variable_value : null,
      module.vm_config.wireguard_public_key,
    "There was an error retrieving the public key. It can be retrieved by logging into the VM in the file at '/etc/wireguard/public.key'. Sometimes re-running 'plan' or 'apply' can resolve this.")
    port          = var.wireguard_config.enable ? var.wireguard_config.port : null
    server_ip     = var.wireguard_config.enable ? google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip : null
    client_config = module.vm_config.wireguard_client_config
  }
}
