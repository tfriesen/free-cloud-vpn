module "azure" {
  source = "./modules/azure"
  count  = var.enable_azure ? 1 : 0
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
  source = "./modules/oracle/cloud_computer"
  count  = var.enable_oracle ? 1 : 0

  tenancy_ocid        = var.oracle_config.tenancy_ocid
  user_ocid           = var.oracle_config.user_ocid
  fingerprint         = var.oracle_config.fingerprint
  private_key_path    = var.oracle_config.private_key_path
  region              = var.oracle_config.region
  compartment_id      = var.oracle_config.compartment_id
  availability_domain = var.oracle_config.availability_domain
  subnet_id           = var.oracle_config.subnet_id
  image_id            = var.oracle_config.image_id
  shape               = var.oracle_config.shape
  display_name        = try(var.oracle_config.display_name, "free-tier-vm")

  # Pass-throughs for vm_config
  vm_username          = var.gcp_vm_username
  ssh_keys             = ""
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
  ssh_ports            = var.ssh_ports
}
