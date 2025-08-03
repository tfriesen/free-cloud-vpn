locals {
  effective_ssh_key = var.ssh_keys != "" ? var.ssh_keys : "${chomp(tls_private_key.generated_key[0].public_key_openssh)} ${chomp(var.vm_username)}"
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

  #Google-specific constants
  vm_guest_attr_namespace = "free-tier-vm-guestattr-namespace"
  wg_pubkey_attr_key      = "wireguard-public-key"
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
  length  = 16
  special = false
}

resource "random_integer" "pingtunnel_key" {
  count = var.enable_pingtunnel && var.pingtunnel_key == -1 ? 1 : 0
  min   = 1000
  max   = 9999
}

resource "tls_private_key" "wireguard" {
  count     = var.wireguard_config.enable ? 1 : 0
  algorithm = "ED25519"
}

resource "tls_private_key" "proxy" {
  count     = local.has_proxy_domain ? 0 : 1
  algorithm = "ED25519"
}

resource "tls_self_signed_cert" "proxy" {
  count           = local.has_proxy_domain ? 0 : 1
  private_key_pem = tls_private_key.proxy[0].private_key_pem

  subject {
    common_name = "ACME, Inc."
  }

  dns_names = ["ACME, Inc."]

  validity_period_hours = 8760 # 1 year

  allowed_uses = [
    "key_encipherment",
    "digital_signature",
    "server_auth",
  ]
}

# Startup script template variables
locals {
  startup_script_vars = {
    # Path and SSH
    path      = path.module
    ssh_ports = var.ssh_ports

    # Instance-specific
    cloud_provider = var.cloud_provider
    arch           = var.arch

    # Custom user shell hooks
    custom_pre_config  = var.custom_pre_config
    custom_post_config = var.custom_post_config

    # WireGuard
    wireguard_enabled       = var.wireguard_config.enable
    wireguard_private_key   = local.wireguard_private_key
    wireguard_server_ip     = local.wireguard_server_ip
    wireguard_config        = var.wireguard_config
    vm_guest_attr_namespace = local.vm_guest_attr_namespace
    wg_pubkey_attr_key      = local.wg_pubkey_attr_key

    # Pingtunnel
    pingtunnel_enabled = var.enable_pingtunnel
    pingtunnel_key     = local.effective_pingtunnel_key

    # Proxy/HTTPS
    effective_proxy_password   = local.effective_proxy_password
    has_proxy_domain           = local.has_proxy_domain
    https_proxy_domain         = var.https_proxy_domain != "" ? var.https_proxy_domain : "proxy.local"
    tls_self_signed_cert_proxy = local.has_proxy_domain ? "" : tls_self_signed_cert.proxy[0].cert_pem
    tls_private_key_proxy_cert = local.has_proxy_domain ? "" : tls_private_key.proxy[0].private_key_pem

    # DNS Tunnel
    dns_tunnel_enabled     = var.dns_tunnel_config.enable
    effective_dns_password = local.effective_dns_password
    dns_tunnel_config      = var.dns_tunnel_config

    # IPSec VPN
    ipsec_vpn_enabled      = var.ipsec_vpn_config.enable
    vpn_client_ip_start    = local.vpn_client_ip_start
    vpn_client_ip_end      = local.vpn_client_ip_end
    vpn_server_ip          = local.vpn_server_ip
    effective_vpn_username = local.effective_vpn_username
    effective_vpn_password = local.effective_vpn_password
    effective_ipsec_psk    = local.effective_ipsec_psk

    #Google-specific constants
    vm_guest_attr_namespace = local.vm_guest_attr_namespace
    wg_pubkey_attr_key      = local.wg_pubkey_attr_key
  }
}
