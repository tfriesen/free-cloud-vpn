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

  vm_username                   = var.vm_username
  dns_tunnel_config             = var.dns_tunnel_config
  dns_tunnel_password           = var.dns_tunnel_password
  https_proxy_domain            = var.https_proxy_domain
  https_proxy_password          = var.https_proxy_password
  https_proxy_external_cert_pem = var.https_proxy_external_cert_pem
  https_proxy_external_key_pem  = var.https_proxy_external_key_pem
  enable_pingtunnel             = var.enable_pingtunnel
  pingtunnel_key                = var.pingtunnel_key
  pingtunnel_aes_key            = var.pingtunnel_aes_key
  custom_pre_config             = var.custom_pre_config
  custom_post_config            = var.custom_post_config
  ipsec_vpn_config              = var.ipsec_vpn_config
  ipsec_vpn_secrets             = var.ipsec_vpn_secrets
  wireguard_config              = var.wireguard_config
  ssh_ports                     = var.ssh_ports

  # Ensure API is enabled and ready before creating compute resources
  depends_on = [time_sleep.wait_compute_api]
}

locals {
  alert_email = var.alert_email != null ? [var.alert_email] : []
}

# Create notification channel for email alerts
resource "google_monitoring_notification_channel" "email" {
  count        = var.alert_email != null ? 1 : 0
  display_name = "Network Usage Alert Email"
  type         = "email"
  labels = {
    email_address = var.alert_email
  }
}

# Monitor network egress approaching free tier limit. Not sure this is monitoring the right metric,
# or even the right amount. I believe there are exceptions for traffic to Google services, for example.
resource "google_monitoring_alert_policy" "network_usage" {
  count = var.alert_email != null ? 1 : 0

  display_name = "Network Usage Alert (Free Tier)"
  combiner     = "OR"

  conditions {
    display_name = "Network egress approaching free tier limit"
    condition_threshold {
      filter          = "metric.type=\"compute.googleapis.com/instance/network/sent_bytes_count\" AND resource.type=\"gce_instance\""
      duration        = "3600s" # 1 hour
      comparison      = "COMPARISON_GT"
      threshold_value = 194560000000 # 90% of 200GB

      aggregations {
        alignment_period     = "3600s"
        per_series_aligner   = "ALIGN_RATE"
        cross_series_reducer = "REDUCE_SUM"
      }

      trigger {
        count = 1
      }
    }
  }

  notification_channels = [for channel in google_monitoring_notification_channel.email : channel.name]

  documentation {
    content   = "Network egress is approaching the Google Cloud free tier limit of 200GB per month. Consider reducing network usage to avoid charges."
    mime_type = "text/markdown"
  }
}
