# DNS records for provider subdomains

# Subdomain A records per enabled provider (e.g., gcp.example.com -> provider IPv4)
resource "cloudflare_dns_record" "subdomain_a" {
  for_each = var.provider_hosts

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "${each.key}.${local.zone_name}"
  type    = "A"
  content = each.value.ipv4
  proxied = var.config.manage_universal_ssl
  ttl     = var.config.manage_universal_ssl ? 1 : 300
}

# Apex/root A records pointing to each provider IPv4 (round-robin at root)
resource "cloudflare_dns_record" "root_a" {
  for_each = var.provider_hosts

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = local.zone_name
  type    = "A"
  content = each.value.ipv4
  proxied = var.config.manage_universal_ssl
  ttl     = var.config.manage_universal_ssl ? 1 : 300
}

# Raw (unproxied) A records per provider: raw.<label>.<domain>
resource "cloudflare_dns_record" "raw_subdomain_a" {
  for_each = var.provider_hosts

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "raw.${each.key}.${local.zone_name}"
  type    = "A"
  content = each.value.ipv4
  proxied = false
  ttl     = 300
}

# Subdomain AAAA records per enabled provider when IPv6 is provided
resource "cloudflare_dns_record" "subdomain_aaaa" {
  for_each = { for k, v in var.provider_hosts : k => v if v.ipv6_enabled }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "${each.key}.${local.zone_name}"
  type    = "AAAA"
  content = each.value.ipv6
  proxied = var.config.manage_universal_ssl
  ttl     = var.config.manage_universal_ssl ? 1 : 300
}

# Apex/root AAAA records pointing to each IPv6-enabled provider
resource "cloudflare_dns_record" "root_aaaa" {
  for_each = { for k, v in var.provider_hosts : k => v if v.ipv6_enabled }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = local.zone_name
  type    = "AAAA"
  content = each.value.ipv6
  proxied = var.config.manage_universal_ssl
  ttl     = var.config.manage_universal_ssl ? 1 : 300
}

# Raw (unproxied) AAAA records per provider when IPv6 is provided
resource "cloudflare_dns_record" "raw_subdomain_aaaa" {
  for_each = { for k, v in var.provider_hosts : k => v if v.ipv6_enabled }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "raw.${each.key}.${local.zone_name}"
  type    = "AAAA"
  content = each.value.ipv6
  proxied = false
  ttl     = 300
}

# If dns_tunnel is enabled for a provider, delegate id.<label>.<domain> back to <label>.<domain>
resource "cloudflare_dns_record" "dns_tunnel_ns" {
  for_each = { for k, v in var.provider_hosts : k => v if try(v.dns_tunnel_enable, false) }

  zone_id = data.cloudflare_zones.this.result[0].id
  name    = "ns.${each.key}.${local.zone_name}"
  type    = "NS"
  content = "raw.${each.key}.${local.zone_name}"
  proxied = false
  ttl     = 300
}
