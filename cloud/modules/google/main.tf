# Enable the Compute Engine API
resource "google_project_service" "compute" {
  service            = "compute.googleapis.com"
  disable_on_destroy = false

  timeouts {
    create = "30m"
    update = "40m"
  }
}

# Wait for API to be ready before creating resources
resource "time_sleep" "wait_compute_api" {
  depends_on = [google_project_service.compute]

  # Allow time for the API to become fully enabled
  create_duration = "30s"
}

module "cloud_computer" {
  source = "./cloud_computer"
  
  vm_username = var.vm_username
  enable_dns_tunnel = var.enable_dns_tunnel
  dns_tunnel_password = var.dns_tunnel_password
  dns_tunnel_domain = var.dns_tunnel_domain
  dns_tunnel_ip     = var.dns_tunnel_ip

  # Ensure API is enabled and ready before creating compute resources
  depends_on = [time_sleep.wait_compute_api]
}
