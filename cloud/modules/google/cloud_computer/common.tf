locals {
  effective_ssh_key = var.ssh_keys != "" ? var.ssh_keys : "${chomp(tls_private_key.generated_key[0].public_key_openssh)} ${var.vm_username}"
  effective_dns_password = var.dns_tunnel_password != "" ? var.dns_tunnel_password : (
    var.dns_tunnel_config.enable ? random_password.dns_tunnel[0].result : ""
  )
  effective_proxy_password = var.https_proxy_password != "" ? var.https_proxy_password : random_password.proxy[0].result
  has_proxy_domain         = var.https_proxy_domain != ""
  effective_vpn_username   = var.ipsec_vpn_config.username != "" ? var.ipsec_vpn_config.username : var.vm_username
  effective_vpn_password = var.ipsec_vpn_secrets.password != "" ? var.ipsec_vpn_secrets.password : (
    var.ipsec_vpn_config.enable ? random_password.vpn[0].result : ""
  )
  effective_ipsec_psk = var.ipsec_vpn_secrets.psk != "" ? var.ipsec_vpn_secrets.psk : (
    var.ipsec_vpn_config.enable ? random_password.ipsec_psk[0].result : ""
  )
  effective_pingtunnel_key = var.pingtunnel_key != -1 ? var.pingtunnel_key : (
    var.enable_pingtunnel ? random_integer.pingtunnel_key[0].result : -1
  )
  vpn_client_network    = split("/", var.ipsec_vpn_config.client_ip_pool)[0]
  vpn_client_netmask    = cidrnetmask(var.ipsec_vpn_config.client_ip_pool)
  vpn_server_ip         = cidrhost(var.ipsec_vpn_config.client_ip_pool, 1)
  vpn_client_ip_start   = cidrhost(var.ipsec_vpn_config.client_ip_pool, 100)
  vpn_client_ip_end     = cidrhost(var.ipsec_vpn_config.client_ip_pool, 200)
  wireguard_server_ip   = replace(var.wireguard_config.client_ip, "2/24", "1/24") # Replace last octet with 1
  wireguard_private_key = var.wireguard_config.enable ? tls_private_key.wireguard[0].private_key_pem : ""
}

resource "tls_private_key" "generated_key" {
  count     = var.ssh_keys == "" ? 1 : 0
  algorithm = "ED25519"
}

resource "random_password" "dns_tunnel" {
  count   = var.dns_tunnel_config.enable && var.dns_tunnel_password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "proxy" {
  count   = var.https_proxy_password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "vpn" {
  count   = var.ipsec_vpn_config.enable && var.ipsec_vpn_secrets.password == "" ? 1 : 0
  length  = 16
  special = false
}

resource "random_password" "ipsec_psk" {
  count   = var.ipsec_vpn_config.enable && var.ipsec_vpn_secrets.psk == "" ? 1 : 0
  length  = 32
  special = false
}

resource "random_integer" "pingtunnel_key" {
  count = var.enable_pingtunnel && var.pingtunnel_key == -1 ? 1 : 0
  min   = 1
  max   = 2147483647
}

resource "tls_private_key" "wireguard" {
  count     = var.wireguard_config.enable ? 1 : 0
  algorithm = "ED25519"
}

resource "tls_private_key" "proxy_cert" {
  count     = local.has_proxy_domain ? 0 : 1
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "proxy_cert" {
  count           = local.has_proxy_domain ? 0 : 1
  private_key_pem = tls_private_key.proxy_cert[0].private_key_pem

  subject {
    common_name  = "acme.local"
    organization = "Acme, Inc."
  }

  validity_period_hours = 87600
  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}
