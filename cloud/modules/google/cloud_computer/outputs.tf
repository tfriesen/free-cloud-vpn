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

output "pingtunnel_key" {
  description = "The key for pingtunnel authentication (only if enabled and auto-generated)"
  value       = var.enable_pingtunnel && var.pingtunnel_key == -1 ? local.effective_pingtunnel_key : null
  sensitive   = true
}

output "dns_tunnel_password" {
  description = "The password for the DNS tunnel (only if enabled and auto-generated)"
  value       = var.dns_tunnel_config.enable && var.dns_tunnel_password == "" ? local.effective_dns_password : null
  sensitive   = true
}

output "dns_tunnel_domain" {
  description = "The domain configured for the DNS tunnel (only if enabled)"
  value       = var.dns_tunnel_config.enable ? var.dns_tunnel_config.domain : null
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

output "ipsec_vpn" {
  description = "IPSec/IKEv2 VPN configuration and status"
  value = {
    enabled        = var.ipsec_vpn_config.enable
    username       = var.ipsec_vpn_config.enable ? local.effective_vpn_username : null
    client_ip_pool = var.ipsec_vpn_config.enable ? var.ipsec_vpn_config.client_ip_pool : null
    server_ip      = var.ipsec_vpn_config.enable ? local.vpn_server_ip : null
  }
}

output "ipsec_vpn_secrets" {
  description = "IPSec/IKEv2 VPN sensitive configuration values"
  value = {
    password = var.ipsec_vpn_config.enable && var.ipsec_vpn_secrets.password == "" ? local.effective_vpn_password : null
  }
  sensitive = true
}

output "wireguard" {
  description = "WireGuard VPN configuration and status"
  value = {
    enabled    = var.wireguard_config.enable
    public_key = coalesce(var.wireguard_config.enable ? data.google_compute_instance_guest_attributes.wg_public_key[0].variable_value : null, "There was an error retrieving the public key. It can be retrieved by logging into the VM in the file at '/etc/wireguard/public.key'. Sometimes re-running 'plan' or 'apply' can resolve this.")
    port       = var.wireguard_config.enable ? var.wireguard_config.port : null
    server_ip  = var.wireguard_config.enable ? local.wireguard_server_ip : null
    client_config = var.wireguard_config.enable ? templatefile(
      "${path.module}/templates/wireguard-client.conf.tpl",
      {
        client_ip     = var.wireguard_config.client_ip
        server_pubkey = coalesce(data.google_compute_instance_guest_attributes.wg_public_key[0].variable_value, "There was an error retrieving the public key. It can be retrieved by logging into the VM in the file at `/etc/wireguard/public.key`")
        server_port   = var.wireguard_config.port
        server_ip     = google_compute_instance.free_tier_vm.network_interface[0].access_config[0].nat_ip
      }
    ) : null
  }
}
