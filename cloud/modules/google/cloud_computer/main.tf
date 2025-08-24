locals {
  vm_guest_attr_namespace = "free-tier-vm-guestattr-namespace"
  wg_pubkey_attr_key      = "wireguard-public-key"
}

# Use the provider-agnostic VM configuration module
module "vm_config" {
  source = "../../vm_config"

  vm_username                   = var.vm_username
  cloud_provider                = "google"
  arch                          = "x86_64"
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
}


resource "google_service_account" "vm_service_account" {
  account_id   = "free-tier-vm-sa"
  display_name = "Service Account for Free Tier VM"
}

resource "google_project_iam_binding" "vm_service_account_compute_instance_admin" {
  project = var.project_id == "" ? google_compute_instance.free_tier_vm.project : var.project_id
  role    = "roles/compute.instanceAdmin"

  members = [
    "serviceAccount:${google_service_account.vm_service_account.email}",
  ]
}

resource "google_compute_instance" "free_tier_vm" {
  name         = "free-tier-vm"
  machine_type = "e2-micro"
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 30
      type  = "pd-standard"
    }
  }

  network_interface {
    network = "default"
    access_config {
      network_tier = var.network_tier
    }
  }

  metadata = {
    ssh-keys                = "${var.vm_username}:${module.vm_config.effective_ssh_key}"
    enable-guest-attributes = "TRUE"
  }

  metadata_startup_script = module.vm_config.startup_script

  service_account {
    email  = google_service_account.vm_service_account.email
    scopes = ["cloud-platform"]
  }

  tags = ["http-server", "https-server"]

  lifecycle {
    ignore_changes = [
      metadata["ssh-keys"],
    ]
  }
}

data "google_compute_instance_guest_attributes" "wg_public_key" {
  count        = var.wireguard_config.enable ? 1 : 0
  name         = google_compute_instance.free_tier_vm.name
  zone         = var.zone
  variable_key = "${local.vm_guest_attr_namespace}/${local.wg_pubkey_attr_key}"

  depends_on = [google_compute_instance.free_tier_vm]
}
