# Network configuration for Google Cloud module

# Derive firewall ports and flags from module inputs (same logic as vm_config outputs)
locals {
  firewall_tcp_ports = concat(
    ["53", "80", "443"], # DNS and HTTPS
    [for port in var.ssh_ports : tostring(port)]
  )

  firewall_udp_ports = concat(
    ["53", "500", "4500"],
    var.wireguard_config.enable ? [tostring(var.wireguard_config.port)] : []
  )

  enable_icmp = var.enable_pingtunnel
  enable_esp  = var.ipsec_vpn_config.enable
  enable_ah   = var.ipsec_vpn_config.enable
}

resource "google_compute_firewall" "allow_inbound" {
  name    = "allow-inbound-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = local.firewall_tcp_ports
  }

  allow {
    protocol = "udp"
    ports    = local.firewall_udp_ports
  }

  dynamic "allow" {
    for_each = local.enable_icmp ? [1] : []
    content {
      protocol = "icmp"
    }
  }

  dynamic "allow" {
    for_each = local.enable_esp ? [1] : []
    content {
      protocol = "esp"
    }
  }

  dynamic "allow" {
    for_each = local.enable_ah ? [1] : []
    content {
      protocol = "ah"
    }
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}
