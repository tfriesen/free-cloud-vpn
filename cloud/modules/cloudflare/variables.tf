variable "enable" {
  description = "Enable Cloudflare configuration"
  type        = bool
  default     = true
}

variable "config" {
  description = "Cloudflare configuration inputs (excluding the enable flag)"
  type = object({
    domain                     = string
    manage_universal_ssl       = optional(bool, true)
    manage_origin_cert         = optional(bool, true)
    origin_cert_validity_years = optional(number, 15)
    origin_cert_hostnames      = optional(list(string), [])
  })
}

variable "provider_hosts" {
  description = "Map of provider labels to settings for DNS records (ipv4/ipv6 and whether dns_tunnel is enabled on that provider). Keys are provider labels like 'gcp' or 'oci'."
  type = map(object({
    enabled           = bool
    ipv4              = optional(string)
    ipv6              = optional(string)
    dns_tunnel_enable = optional(bool, false)
  }))
  default = {}
}
