variable "vm_username" {
  description = "The username for the VM instance"
  type        = string
  default     = "free-vpn-user"
}

variable "enable_dns_tunnel" {
  description = "Whether to enable the DNS tunnel using iodine"
  type        = bool
  default     = true
}

variable "dns_tunnel_password" {
  description = "Password for the DNS tunnel. If not specified, a random password will be generated"
  type        = string
  default     = ""
}

variable "dns_tunnel_domain" {
  description = "Domain to use for the DNS tunnel. Required if enable_dns_tunnel is true"
  type        = string
  default     = null

  validation {
    condition     = var.enable_dns_tunnel == false || var.dns_tunnel_domain != null
    error_message = "dns_tunnel_domain must be specified when enable_dns_tunnel is true"
  }
}

variable "dns_tunnel_ip" {
  description = "IP address to use for the iodine DNS tunnel"
  type        = string
  default     = "172.31.9.1"
}
