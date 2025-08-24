module "azure" {
  source = "./modules/azure"
  count  = var.enable_azure ? 1 : 0
}

module "cloudflare" {
  source = "./modules/cloudflare"
  count  = var.enable_cloudflare && var.cloudflare_config.domain != "" ? 1 : 0

  enable = var.enable_cloudflare
  config = var.cloudflare_config

  provider_hosts = merge(
    var.enable_google ? {
      gcp = {
        ipv4              = module.google[0].vm_ip_address != null ? module.google[0].vm_ip_address : ""
        ipv6_enabled      = false
        dns_tunnel_enable = var.dns_tunnel_config.enable
      }
    } : {},
    var.enable_oracle ? {
      oci = {
        ipv4              = module.oracle[0].vm_ip_address != null ? module.oracle[0].vm_ip_address : ""
        ipv6              = var.ipv6_enabled ? module.oracle[0].vm_ipv6_address : null
        ipv6_enabled      = var.ipv6_enabled
        dns_tunnel_enable = var.dns_tunnel_config.enable
      }
    } : {}
  )
}

module "aws" {
  source = "./modules/aws"
  count  = var.enable_aws ? 1 : 0

  alert_email = var.alert_email
}

module "google" {
  source = "./modules/google"
  count  = var.enable_google ? 1 : 0

  alert_email = var.alert_email

  vm_username                   = var.gcp_vm_username
  dns_tunnel_config             = var.enable_cloudflare ? merge(var.dns_tunnel_config, { domain = "ns.gcp.${var.cloudflare_config.domain}" }) : var.dns_tunnel_config
  dns_tunnel_password           = var.dns_tunnel_password
  enable_pingtunnel             = var.enable_pingtunnel
  pingtunnel_key                = var.pingtunnel_key
  pingtunnel_aes_key            = var.pingtunnel_aes_key
  custom_pre_config             = var.custom_pre_config
  custom_post_config            = var.custom_post_config
  https_proxy_password          = var.https_proxy_password
  https_proxy_domain            = var.https_proxy_domain == "" ? "gcp.${var.cloudflare_config.domain}" : var.https_proxy_domain
  https_proxy_external_cert_pem = try(module.cloudflare[0].origin_certificate_pem, "")
  https_proxy_external_key_pem  = try(module.cloudflare[0].origin_private_key_pem, "")
  ipsec_vpn_config              = var.ipsec_vpn_config
  ipsec_vpn_secrets             = var.ipsec_vpn_secrets
  wireguard_config              = var.wireguard_config
  ssh_ports                     = var.ssh_ports
}

module "oracle" {
  source = "./modules/oracle"
  count  = var.enable_oracle ? 1 : 0

  tenancy_ocid = var.tenancy_ocid
  alert_email  = var.alert_email
  ipv6_enabled = var.ipv6_enabled

  # Pass-throughs for vm_config
  vm_username                   = var.gcp_vm_username
  custom_pre_config             = var.custom_pre_config
  custom_post_config            = var.custom_post_config
  dns_tunnel_config             = var.enable_cloudflare ? merge(var.dns_tunnel_config, { domain = "ns.oci.${var.cloudflare_config.domain}" }) : var.dns_tunnel_config
  dns_tunnel_password           = var.dns_tunnel_password
  https_proxy_domain            = var.https_proxy_domain == "" ? "oci.${var.cloudflare_config.domain}" : var.https_proxy_domain
  https_proxy_password          = var.https_proxy_password
  https_proxy_external_cert_pem = try(module.cloudflare[0].origin_certificate_pem, "")
  https_proxy_external_key_pem  = try(module.cloudflare[0].origin_private_key_pem, "")
  ipsec_vpn_config              = var.ipsec_vpn_config
  ipsec_vpn_secrets             = var.ipsec_vpn_secrets
  wireguard_config              = var.wireguard_config
  enable_pingtunnel             = var.enable_pingtunnel
  pingtunnel_key                = var.pingtunnel_key
  pingtunnel_aes_key            = var.pingtunnel_aes_key
  ssh_ports                     = var.ssh_ports
}
