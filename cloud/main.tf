module "azure" {
  source = "./modules/azure"
  count  = var.enable_azure ? 1 : 0
}

module "cloudflare" {
  source = "./modules/cloudflare"
  count  = var.enable_cloudflare && var.cloudflare_config.domain != "" ? 1 : 0

  enable = var.enable_cloudflare
  config = var.cloudflare_config

  provider_hosts = {
    gcp = {
      enabled           = var.enable_google
      ipv4              = try(module.google[0].vm_ip_address, null)
      ipv6              = null
      dns_tunnel_enable = var.dns_tunnel_config.enable
    }
    oci = {
      enabled           = var.enable_oracle
      ipv4              = try(module.oracle[0].vm_ip_address, null)
      ipv6              = try(module.oracle[0].vm_ipv6_address, null)
      dns_tunnel_enable = var.dns_tunnel_config.enable
    }
  }
}

module "aws" {
  source = "./modules/aws"
  count  = var.enable_aws ? 1 : 0

  alert_email = var.alert_email
}

module "google" {
  source = "./modules/google"
  count  = var.enable_google ? 1 : 0

  vm_username          = var.gcp_vm_username
  dns_tunnel_config    = var.dns_tunnel_config
  dns_tunnel_password  = var.dns_tunnel_password
  enable_pingtunnel    = var.enable_pingtunnel
  pingtunnel_key       = var.pingtunnel_key
  pingtunnel_aes_key   = var.pingtunnel_aes_key
  custom_pre_config    = var.custom_pre_config
  custom_post_config   = var.custom_post_config
  alert_email          = var.alert_email
  https_proxy_password = var.https_proxy_password
  https_proxy_domain   = var.https_proxy_domain
  ipsec_vpn_config     = var.ipsec_vpn_config
  ipsec_vpn_secrets    = var.ipsec_vpn_secrets
  wireguard_config     = var.wireguard_config
  ssh_ports            = var.ssh_ports
}

module "oracle" {
  source = "./modules/oracle"
  count  = var.enable_oracle ? 1 : 0

  tenancy_ocid = var.tenancy_ocid
  alert_email  = var.alert_email
  ipv6_enabled = var.ipv6_enabled

  # Pass-throughs for vm_config
  vm_username          = var.gcp_vm_username
  custom_pre_config    = var.custom_pre_config
  custom_post_config   = var.custom_post_config
  dns_tunnel_config    = var.dns_tunnel_config
  dns_tunnel_password  = var.dns_tunnel_password
  https_proxy_domain   = var.https_proxy_domain
  https_proxy_password = var.https_proxy_password
  ipsec_vpn_config     = var.ipsec_vpn_config
  ipsec_vpn_secrets    = var.ipsec_vpn_secrets
  wireguard_config     = var.wireguard_config
  enable_pingtunnel    = var.enable_pingtunnel
  pingtunnel_key       = var.pingtunnel_key
  pingtunnel_aes_key   = var.pingtunnel_aes_key
  ssh_ports            = var.ssh_ports
}
