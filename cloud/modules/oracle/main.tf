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
  compartment_id = data.oci_identity_tenancy.tenancy.id
  operating_system         = "Canonical Ubuntu"
  operating_system_version = "22.04"
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

# Create VCN (Virtual Cloud Network)
resource "oci_core_vcn" "free_tier_vcn" {
  compartment_id = oci_identity_compartment.free_tier.id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "free-tier-vcn"
  dns_label      = "freetiervcn"
}

# Create Internet Gateway
resource "oci_core_internet_gateway" "free_tier_igw" {
  compartment_id = oci_identity_compartment.free_tier.id
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "free-tier-igw"
}

# Create Route Table
resource "oci_core_route_table" "free_tier_rt" {
  compartment_id = oci_identity_compartment.free_tier.id
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "free-tier-rt"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.free_tier_igw.id
  }
}

# Create Security List
resource "oci_core_security_list" "free_tier_sl" {
  compartment_id = oci_identity_compartment.free_tier.id
  vcn_id         = oci_core_vcn.free_tier_vcn.id
  display_name   = "free-tier-sl"

  # Egress rules - allow all outbound
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # Ingress rules - SSH, HTTPS, and VPN ports
  dynamic "ingress_security_rules" {
    for_each = var.ssh_ports
    content {
      protocol = "6" # TCP
      source   = "0.0.0.0/0"
      tcp_options {
        min = ingress_security_rules.value
        max = ingress_security_rules.value
      }
    }
  }

  # HTTPS (443)
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 443
      max = 443
    }
  }

  # DNS (53) TCP and UDP
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 53
      max = 53
    }
  }

  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 53
      max = 53
    }
  }

  # WireGuard (default 51820) UDP
  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = tonumber(var.wireguard_config.port)
      max = tonumber(var.wireguard_config.port)
    }
  }

  # IPSec (500, 4500) UDP
  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 500
      max = 500
    }
  }

  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 4500
      max = 4500
    }
  }

  # ICMP for pingtunnel
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
  }
}

# Create Subnet
resource "oci_core_subnet" "free_tier_subnet" {
  compartment_id      = oci_identity_compartment.free_tier.id
  vcn_id              = oci_core_vcn.free_tier_vcn.id
  cidr_block          = "10.0.1.0/24"
  display_name        = "free-tier-subnet"
  dns_label           = "freetiersubnet"
  route_table_id      = oci_core_route_table.free_tier_rt.id
  security_list_ids   = [oci_core_security_list.free_tier_sl.id]
  prohibit_public_ip_on_vnic = false
}

module "cloud_computer" {
  source = "./cloud_computer"

  compartment_id      = oci_identity_compartment.free_tier.id
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  subnet_id           = oci_core_subnet.free_tier_subnet.id
  image_id            = data.oci_core_images.ubuntu_images.images[0].id
  shape               = var.shape
  display_name        = var.display_name

  vm_username          = var.vm_username
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

locals {
  alert_email = var.alert_email != null ? [var.alert_email] : []
}

# Oracle Cloud doesn't have the same monitoring/alerting setup as Google Cloud
# This is a placeholder for future Oracle-specific monitoring features
# For now, we'll just output a message if alert_email is provided
resource "null_resource" "oracle_alert_placeholder" {
  count = var.alert_email != null ? 1 : 0
  
  provisioner "local-exec" {
    command = "echo 'Oracle Cloud monitoring alerts not yet implemented. Alert email: ${var.alert_email}'"
  }
}
