# Get the tenancy OCID
data "oci_identity_tenancy" "tenancy" {
  tenancy_id = var.tenancy_ocid
}

# Get availability domains
data "oci_identity_availability_domains" "ads" {
  compartment_id = data.oci_identity_tenancy.tenancy.id
}

# Get the latest Ubuntu 22.04 LTS image for ARM (A1 shape)
data "oci_core_images" "ubuntu_images" {
  compartment_id           = data.oci_identity_tenancy.tenancy.id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "24.04"
  shape                    = var.shape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Create a compartment for the free tier resources
resource "oci_identity_compartment" "free_tier" {
  compartment_id = data.oci_identity_tenancy.tenancy.id
  description    = "Compartment for free tier VPN resources"
  name           = var.compartment_name
  enable_delete  = true
}



module "cloud_computer" {
  source = "./cloud_computer"

  compartment_id      = oci_identity_compartment.free_tier.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_id           = oci_core_subnet.free_tier_subnet.id
  image_id            = data.oci_core_images.ubuntu_images.images[0].id
  shape               = var.shape
  display_name        = var.display_name

  vm_username                   = var.vm_username
  ssh_keys                      = var.ssh_keys
  custom_pre_config             = var.custom_pre_config
  custom_post_config            = var.custom_post_config
  dns_tunnel_config             = var.dns_tunnel_config
  dns_tunnel_password           = var.dns_tunnel_password
  https_proxy_domain            = var.https_proxy_domain
  https_proxy_password          = var.https_proxy_password
  https_proxy_external_cert_pem = var.https_proxy_external_cert_pem
  https_proxy_external_key_pem  = var.https_proxy_external_key_pem
  ipsec_vpn_config              = var.ipsec_vpn_config
  ipsec_vpn_secrets             = var.ipsec_vpn_secrets
  wireguard_config              = var.wireguard_config
  enable_pingtunnel             = var.enable_pingtunnel
  pingtunnel_key                = var.pingtunnel_key
  pingtunnel_aes_key            = var.pingtunnel_aes_key
  ssh_ports                     = var.ssh_ports
  ipv6_enabled                  = var.ipv6_enabled
}

locals {
  alert_email = var.alert_email != null ? [var.alert_email] : []
}

# Oracle Cloud doesn't have the same monitoring/alerting setup as Google Cloud
# This is a placeholder for future Oracle-specific monitoring features
# For now, we'll just output a message if alert_email is provided.
# It also matters less if you're on the Always Free tier, as you can't actually get charged
resource "null_resource" "oracle_alert_placeholder" {
  count = var.alert_email != null ? 1 : 0

  provisioner "local-exec" {
    command = "echo 'Oracle Cloud monitoring alerts not yet implemented. Alert email: ${var.alert_email}'"
  }
}
