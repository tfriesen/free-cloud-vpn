locals {
  vm_guest_attr_namespace = "free-tier-vm-guestattr-namespace"
  wg_pubkey_attr_key      = "wireguard-public-key"
}

resource "google_compute_firewall" "allow_inbound" {
  name    = "allow-inbound-ports"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["22", "53", "80", "443"]
  }
  allow {
    protocol = "udp"
    ports = concat(
      ["53", "500", "4500"],
      var.wireguard_config.enable ? [var.wireguard_config.port] : []
    )
  }

  dynamic "allow" {
    for_each = var.enable_icmp_tunnel ? [1] : []
    content {
      protocol = "icmp"
    }
  }

  dynamic "allow" {
    for_each = var.ipsec_vpn_config.enable ? [1] : []
    content {
      protocol = "esp"
    }
  }

  dynamic "allow" {
    for_each = var.ipsec_vpn_config.enable ? [1] : []
    content {
      protocol = "ah"
    }
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["http-server", "https-server"]
}

resource "google_service_account" "vm_service_account" {
  account_id   = "free-tier-vm-sa"
  display_name = "Service Account for Free Tier VM"
  description  = "Minimal service account for the free tier VM instance"
}

resource "google_project_iam_member" "instance_log_writer" {
  project = google_compute_instance.free_tier_vm.project
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_project_iam_member" "instance_metric_writer" {
  project = google_compute_instance.free_tier_vm.project
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.vm_service_account.email}"
}

resource "google_compute_instance" "free_tier_vm" {
  name         = "free-tier-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
      size  = 10
    }
  }

  network_interface {
    network    = "default"
    stack_type = "IPV4_ONLY"
    nic_type   = "GVNIC"
    access_config {
      network_tier = var.network_tier
    }
  }

  tags = ["http-server", "https-server"]

  # Use the custom service account
  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup-script.sh.tpl", {
    path = path.module,
    # General
    custom_pre_config  = var.custom_pre_config,
    custom_post_config = var.custom_post_config,
    # WireGuard
    wireguard_enabled       = var.wireguard_config.enable,
    wireguard_private_key   = local.wireguard_private_key,
    wireguard_server_ip     = local.wireguard_server_ip,
    wireguard_config        = var.wireguard_config,
    vm_guest_attr_namespace = local.vm_guest_attr_namespace,
    wg_pubkey_attr_key      = local.wg_pubkey_attr_key,
    # ICMP Tunnel
    icmp_tunnel_enabled = var.enable_icmp_tunnel,
    # Proxy/HTTPS
    effective_proxy_password   = local.effective_proxy_password,
    has_proxy_domain           = local.has_proxy_domain,
    https_proxy_domain         = var.https_proxy_domain,
    tls_self_signed_cert_proxy = local.has_proxy_domain ? "" : tls_self_signed_cert.proxy_cert[0].cert_pem,
    tls_private_key_proxy_cert = local.has_proxy_domain ? "" : tls_private_key.proxy_cert[0].private_key_pem,
    # DNS Tunnel
    dns_tunnel_enabled     = var.dns_tunnel_config.enable,
    effective_dns_password = local.effective_dns_password,
    dns_tunnel_config      = var.dns_tunnel_config,
    # IPSec VPN
    ipsec_vpn_enabled      = var.ipsec_vpn_config.enable,
    effective_ipsec_psk    = local.effective_ipsec_psk,
    vpn_client_ip_start    = local.vpn_client_ip_start,
    vpn_client_ip_end      = local.vpn_client_ip_end,
    vpn_server_ip          = local.vpn_server_ip,
    effective_vpn_username = local.effective_vpn_username,
    effective_vpn_password = local.effective_vpn_password
  })

  metadata = {
    enable-guest-attributes = "true"
    ssh-keys                = "${var.vm_username}:${local.effective_ssh_key}"
  }
}

resource "time_sleep" "wait_for_instance" {
  count           = var.wireguard_config.enable ? 1 : 0
  create_duration = "30s" #minimum time for the instance to be ready
  depends_on = [
    google_compute_instance.free_tier_vm
  ]
  lifecycle {
    # Ensure this resource is recreated if the instance is replaced
    # This is necessary to ensure the guest attributes are fetched after the instance is ready
    replace_triggered_by = [
      google_compute_instance.free_tier_vm
    ]
  }
}

data "google_compute_instance_guest_attributes" "wg_public_key" {
  count        = var.wireguard_config.enable ? 1 : 0
  name         = google_compute_instance.free_tier_vm.name
  zone         = var.zone
  variable_key = "${local.vm_guest_attr_namespace}/${local.wg_pubkey_attr_key}"

  #make sure this runs after the instance is configured
  depends_on = [
    time_sleep.wait_for_instance
  ]
}
