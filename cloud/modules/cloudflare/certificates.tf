# Certificate-related settings and resources

locals {
  origin_hosts = length(var.config.origin_cert_hostnames) > 0 ? var.config.origin_cert_hostnames : [var.config.domain, "*.${var.config.domain}"]
  # Cloudflare origin cert requested_validity is in DAYS. Convert provided years to days (~365x).
  origin_cert_validity_days = floor(var.config.origin_cert_validity_years * 365)
}

# Manage universal SSL and HTTPS settings (optional) via per-setting resources
resource "cloudflare_zone_setting" "always_use_https" {
  count      = var.enable && var.config.manage_universal_ssl ? 1 : 0
  zone_id    = data.cloudflare_zones.this.result[0].id
  setting_id = "always_use_https"
  value      = "off" # we may have need of HTTP
}

resource "cloudflare_zone_setting" "tls_1_3" {
  count      = var.enable && var.config.manage_universal_ssl ? 1 : 0
  zone_id    = data.cloudflare_zones.this.result[0].id
  setting_id = "tls_1_3"
  value      = "on"
}

resource "cloudflare_zone_setting" "min_tls_version" {
  count      = var.enable && var.config.manage_universal_ssl ? 1 : 0
  zone_id    = data.cloudflare_zones.this.result[0].id
  setting_id = "min_tls_version"
  value      = "1.2"
}

# Generate a new private key for the origin certificate
resource "tls_private_key" "origin" {
  count     = var.enable && var.config.manage_origin_cert ? 1 : 0
  algorithm = "ED25519"
}

# Create a CSR covering the desired hostnames
resource "tls_cert_request" "origin" {
  count = var.enable && var.config.manage_origin_cert ? 1 : 0

  private_key_pem = tls_private_key.origin[0].private_key_pem

  subject {
    common_name  = local.origin_hosts[0]
    organization = "Acme, Inc."
  }

  dns_names = local.origin_hosts
}

# Issue a Cloudflare Origin CA certificate for the origin (optional)
resource "cloudflare_origin_ca_certificate" "origin" {
  count              = var.enable && var.config.manage_origin_cert ? 1 : 0
  csr                = tls_cert_request.origin[0].cert_request_pem
  hostnames          = toset(local.origin_hosts)
  request_type       = "origin-ecc"
  requested_validity = local.origin_cert_validity_days
}
