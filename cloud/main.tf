module "azure" {
  source = "./modules/azure"
  count  = var.enable_azure ? 1 : 0
}

module "aws" {
  source      = "./modules/aws"
  count       = var.enable_aws ? 1 : 0

  alert_email = var.alert_email
}

module "google" {
  source      = "./modules/google"
  count       = var.enable_google ? 1 : 0

  vm_username = var.gcp_vm_username
  enable_dns_tunnel = var.enable_dns_tunnel
  dns_tunnel_password = var.dns_tunnel_password
  dns_tunnel_domain = var.dns_tunnel_domain
  dns_tunnel_ip     = var.dns_tunnel_ip
  alert_email = var.alert_email
}
