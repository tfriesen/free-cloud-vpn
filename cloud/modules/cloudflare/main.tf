locals {
  zone_name = var.config.domain
  # Certificate-related locals live in certificates.tf
}

# Data lookup for zone by name (singular data source with filter)
data "cloudflare_zones" "this" {
  name   = local.zone_name
  status = "active"
}
