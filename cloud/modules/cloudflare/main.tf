locals {
  zone_name    = var.config.domain
  origin_hosts = length(var.config.origin_cert_hostnames) > 0 ? var.config.origin_cert_hostnames : [var.config.domain, "*.${var.config.domain}"]
  # Cloudflare origin cert requested_validity is in DAYS. Convert provided years to days (~365x).
  origin_cert_validity_days = floor(var.config.origin_cert_validity_years * 365)
  provider_map              = { for k, v in var.provider_hosts : k => v if v.enabled }
}

# Data lookup for zone by name (singular data source with filter)
data "cloudflare_zones" "this" {
  name   = local.zone_name
  status = "active"
}

# Subdomain A records per enabled provider (e.g., gcp.example.com -> provider IPv4)
resource "cloudflare_dns_record" "subdomain_a" {
  for_each = { for k, v in local.provider_map : k => v if try(v.ipv4, "") != "" }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "${each.key}.${local.zone_name}"
  type    = "A"
  content = each.value.ipv4
  proxied = true
  ttl     = 1
}

# Raw (unproxied) A records per provider: raw.<label>.<domain>
resource "cloudflare_dns_record" "raw_subdomain_a" {
  for_each = { for k, v in local.provider_map : k => v if try(v.ipv4, "") != "" }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "raw.${each.key}.${local.zone_name}"
  type    = "A"
  content = each.value.ipv4
  proxied = false
  ttl     = 300
}

# Subdomain AAAA records per enabled provider when IPv6 is provided
resource "cloudflare_dns_record" "subdomain_aaaa" {
  for_each = { for k, v in local.provider_map : k => v if v.ipv6 != null }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "${each.key}.${local.zone_name}"
  type    = "AAAA"
  content = each.value.ipv6
  proxied = true
  ttl     = 1
}

# Raw (unproxied) AAAA records per provider when IPv6 is provided
resource "cloudflare_dns_record" "raw_subdomain_aaaa" {
  for_each = { for k, v in local.provider_map : k => v if v.ipv6 != null }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "raw.${each.key}.${local.zone_name}"
  type    = "AAAA"
  content = each.value.ipv6
  proxied = false
  ttl     = 300
}

# If dns_tunnel is enabled for a provider, delegate id.<label>.<domain> back to <label>.<domain>
resource "cloudflare_dns_record" "dns_tunnel_ns" {
  for_each = { for k, v in local.provider_map : k => v if try(v.dns_tunnel_enable, false) }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "id.${each.key}.${local.zone_name}"
  type    = "NS"
  content = "${each.key}.${local.zone_name}"
  proxied = false
  ttl     = 300
}

# Manage universal SSL and HTTPS settings (optional) via per-setting resources
resource "cloudflare_zone_setting" "always_use_https" {
  count      = var.enable && var.config.manage_universal_ssl ? 1 : 0
  zone_id    = data.cloudflare_zones.this.result[0].id
  setting_id = "always_use_https"
  value      = "off" #we may have need of HTTP
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

# Generate a new ECDSA private key to match the requested ECC origin cert
resource "tls_private_key" "origin" {
  count     = var.enable && var.config.manage_origin_cert ? 1 : 0
  algorithm = "ED25519"
  #ecdsa_curve = "P256"
}

# Create a CSR covering the desired hostnames
resource "tls_cert_request" "origin" {
  count = var.enable && var.config.manage_origin_cert ? 1 : 0

  private_key_pem = tls_private_key.origin[0].private_key_pem

  subject {
    common_name  = local.zone_name
    organization = "Acme, Inc."
  }

  dns_names = local.origin_hosts
}

# Issue a Cloudflare Origin CA certificate for the origin (optional)
resource "cloudflare_origin_ca_certificate" "origin" {
  count              = var.enable && var.config.manage_origin_cert ? 1 : 0
  csr                = tls_cert_request.origin[0].cert_request_pem
  hostnames          = toset(local.origin_hosts) #toset hopefully avoids sorting issues causing dirty plans
  request_type       = "origin-ecc"
  requested_validity = local.origin_cert_validity_days
}
