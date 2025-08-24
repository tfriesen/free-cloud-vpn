# Create VCN (Virtual Cloud Network)
resource "oci_core_vcn" "free_tier_vcn" {
  compartment_id = oci_identity_compartment.free_tier.id
  cidr_blocks    = ["10.0.0.0/16"]
  display_name   = "free-tier-vcn"
  dns_label      = "freetiervcn"
  is_ipv6enabled = var.ipv6_enabled
  # Let Oracle allocate a GUA /56 when IPv6 is enabled
  # is_oracle_gua_allocation_enabled defaults to true
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

  dynamic "route_rules" {
    for_each = var.ipv6_enabled ? [1] : []
    content {
      destination       = "::/0"
      destination_type  = "CIDR_BLOCK"
      network_entity_id = oci_core_internet_gateway.free_tier_igw.id
    }
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
  dynamic "egress_security_rules" {
    for_each = var.ipv6_enabled ? [1] : []
    content {
      destination = "::/0"
      protocol    = "all"
    }
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
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled ? var.ssh_ports : []
    content {
      protocol = "6" # TCP
      source   = "::/0"
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
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled ? [1] : []
    content {
      protocol = "6" # TCP
      source   = "::/0"
      tcp_options {
        min = 443
        max = 443
      }
    }
  }

  # HTTP (80) - for certbot or other
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "0.0.0.0/0"
    tcp_options {
      min = 80
      max = 80
    }
  }
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled ? [1] : []
    content {
      protocol = "6" # TCP
      source   = "::/0"
      tcp_options {
        min = 80
        max = 80
      }
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
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled ? [1] : []
    content {
      protocol = "6" # TCP
      source   = "::/0"
      tcp_options {
        min = 53
        max = 53
      }
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
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled ? [1] : []
    content {
      protocol = "17" # UDP
      source   = "::/0"
      udp_options {
        min = 53
        max = 53
      }
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
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled && var.wireguard_config.enable ? [1] : []
    content {
      protocol = "17" # UDP
      source   = "::/0"
      udp_options {
        min = tonumber(var.wireguard_config.port)
        max = tonumber(var.wireguard_config.port)
      }
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
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled && var.ipsec_vpn_config.enable ? [1] : []
    content {
      protocol = "17" # UDP
      source   = "::/0"
      udp_options {
        min = 500
        max = 500
      }
    }
  }
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled && var.ipsec_vpn_config.enable ? [1] : []
    content {
      protocol = "17" # UDP
      source   = "::/0"
      udp_options {
        min = 4500
        max = 4500
      }
    }
  }

  # ICMP for pingtunnel
  ingress_security_rules {
    protocol = "1" # ICMP
    source   = "0.0.0.0/0"
  }
  dynamic "ingress_security_rules" {
    for_each = var.ipv6_enabled && var.enable_pingtunnel ? [1] : []
    content {
      protocol = "58" # ICMPv6
      source   = "::/0"
    }
  }
}

# Create Subnet
resource "oci_core_subnet" "free_tier_subnet" {
  compartment_id             = oci_identity_compartment.free_tier.id
  vcn_id                     = oci_core_vcn.free_tier_vcn.id
  cidr_block                 = "10.0.1.0/24"
  display_name               = "free-tier-subnet"
  dns_label                  = "freetiersubnet"
  route_table_id             = oci_core_route_table.free_tier_rt.id
  security_list_ids          = [oci_core_security_list.free_tier_sl.id]
  prohibit_public_ip_on_vnic = false
  ipv6cidr_block             = var.ipv6_enabled ? cidrsubnet(oci_core_vcn.free_tier_vcn.ipv6cidr_blocks[0], 8, 0) : null
}
