terraform {
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = ">= 5.0.0"
    }
  }
}

module "vm_config" {
  source = "../../vm_config"
  # Pass through relevant variables from parent/root
  vm_username          = var.vm_username
  cloud_provider       = "oracle"
  arch                 = "arm64"
  ssh_keys             = var.ssh_keys
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

resource "oci_core_instance" "free_tier_vm" {
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  shape               = var.shape
  display_name        = var.display_name

  # Shape configuration for A1.Flex (ARM) instances
  shape_config {
    ocpus         = var.ocpus
    memory_in_gbs = var.memory_in_gbs
  }

  create_vnic_details {
    assign_public_ip = true
    subnet_id        = var.subnet_id
  }

  source_details {
    source_type = "image"
    source_id   = var.image_id
  }

  metadata = {
    ssh_authorized_keys = module.vm_config.effective_ssh_key
    user_data           = base64encode(module.vm_config.startup_script)
  }
}
