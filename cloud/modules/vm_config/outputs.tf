output "generated_ssh_public_key" {
  value = var.ssh_keys != "" ? null : tls_private_key.generated_key[0].public_key_openssh
}

output "generated_ssh_private_key" {
  value     = var.ssh_keys != "" ? null : tls_private_key.generated_key[0].private_key_openssh
  sensitive = true
}

output "effective_ssh_key" {
  value = local.effective_ssh_key
}

output "pingtunnel_key" {
  description = "The key for pingtunnel authentication (only if enabled and auto-generated)"
  value       = var.enable_pingtunnel && var.pingtunnel_key == -1 ? local.effective_pingtunnel_key : null
  sensitive   = true
}

output "pingtunnel_aes_key" {
  description = "The AES encryption key for pingtunnel (only if enabled and auto-generated)"
  value       = var.enable_pingtunnel && var.pingtunnel_aes_key == "" ? local.effective_pingtunnel_aes_key : null
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

output "https_proxy" {
  description = "Non-sensitive HTTPS proxy configuration"
  value = {
    username = var.https_proxy_config.username
    domain   = var.https_proxy_config.domain != "" ? var.https_proxy_config.domain : "proxy.local"
    cert     = local.has_proxy_domain ? "" : tls_self_signed_cert.proxy[0].cert_pem
  }
}

output "https_proxy_secrets" {
  description = "Sensitive HTTPS proxy secrets (password, private key)"
  value = {
    password         = local.effective_proxy_password
    external_key_pem = var.https_proxy_secrets.external_key_pem
  }
  sensitive = true
}

output "ipsec_vpn_username" {
  description = "The username for the IPSec VPN"
  value       = var.ipsec_vpn_config.enable ? local.effective_vpn_username : null
}

output "ipsec_vpn_password" {
  description = "The password for the IPSec VPN (only if enabled and auto-generated)"
  value       = var.ipsec_vpn_config.enable && var.ipsec_vpn_secrets.password == "" ? local.effective_vpn_password : null
  sensitive   = true
}

output "ipsec_psk" {
  description = "The pre-shared key for IPSec (only if enabled and auto-generated)"
  value       = var.ipsec_vpn_config.enable && var.ipsec_vpn_secrets.psk == "" ? local.effective_ipsec_psk : null
  sensitive   = true
}

output "wireguard_public_key" {
  description = "The public key for WireGuard (only if enabled)"
  value       = var.wireguard_config.enable ? tls_private_key.wireguard[0].public_key_openssh : null
}

output "wireguard_private_key" {
  description = "The private key for WireGuard (only if enabled)"
  value       = var.wireguard_config.enable ? tls_private_key.wireguard[0].private_key_openssh : null
  sensitive   = true
}

output "wireguard_client_config" {
  description = "WireGuard client configuration (only if enabled)"
  value = var.wireguard_config.enable ? templatefile("${path.module}/templates/wireguard-client.conf.tpl", {
    client_private_key = nonsensitive(tls_private_key.wireguard[0].private_key_openssh)
    server_pubkey      = tls_private_key.wireguard[0].public_key_openssh
    client_ip          = var.wireguard_config.client_ip
    server_ip          = local.wireguard_server_ip
    server_port        = var.wireguard_config.port
  }) : null
}

output "startup_script" {
  description = "The rendered startup script for the VM"
  value       = templatefile("${path.module}/templates/startup-script.sh.tpl", local.startup_script_vars)
}

output "ssh_ports" {
  description = "List of SSH ports to configure"
  value       = var.ssh_ports
}

output "firewall_tcp_ports" {
  description = "TCP ports that should be opened in firewall"
  value = concat(
    ["53", "443"],                               # DNS and HTTPS ports (always needed)
    [for port in var.ssh_ports : tostring(port)] # Dynamic SSH ports
  )
}

output "firewall_udp_ports" {
  description = "UDP ports that should be opened in firewall"
  value = concat(
    ["53", "500", "4500"],
    var.wireguard_config.enable ? [var.wireguard_config.port] : []
  )
}

output "enable_icmp" {
  description = "Whether ICMP should be enabled in firewall"
  value       = var.enable_pingtunnel
}

output "enable_esp" {
  description = "Whether ESP protocol should be enabled in firewall"
  value       = var.ipsec_vpn_config.enable
}

output "enable_ah" {
  description = "Whether AH protocol should be enabled in firewall"
  value       = var.ipsec_vpn_config.enable
}
