variable "vm_username" {
  description = "The username for the VM instance"
  type        = string
  default     = "free-vpn-user"
}

variable "dns_tunnel_config" {
  description = "Configuration for the DNS tunnel using iodine"
  type = object({
    enable    = optional(bool, true)
    domain    = string
    server_ip = optional(string, "172.31.9.1")
  })
  default = {
    enable = true
    domain = null
  }
  validation {
    condition     = var.dns_tunnel_config.enable == false || var.dns_tunnel_config.domain != null
    error_message = "domain must be specified when enable is true"
  }
  validation {
    condition     = var.dns_tunnel_config.domain == null || can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,}$", var.dns_tunnel_config.domain))
    error_message = "If provided, domain must be a valid domain name."
  }
}

variable "dns_tunnel_password" {
  description = "Password for the DNS tunnel. If not specified, a random password will be generated"
  type        = string
  default     = ""
  sensitive   = true
}

variable "alert_email" {
  description = "Optional email address to receive Google Cloud free tier alerts"
  type        = string
  default     = null
}

variable "https_proxy_password" {
  description = "Password for the HTTPS proxy. If not specified, a random password will be generated"
  type        = string
  default     = ""
}

variable "https_proxy_domain" {
  description = "Domain to use for the HTTPS proxy's LetsEncrypt certificate. If not specified, a self-signed certificate will be used"
  type        = string
  default     = ""
}

variable "enable_pingtunnel" {
  description = "Whether to enable pingtunnel (ICMP tunneling using pingtunnel project)"
  type        = bool
  default     = false
}

variable "pingtunnel_key" {
  description = "Key for pingtunnel authentication (integer between 0-2147483647). If not specified, a random key will be generated"
  type        = number
  default     = -1
  validation {
    condition     = var.pingtunnel_key == -1 || (var.pingtunnel_key >= 0 && var.pingtunnel_key <= 2147483647)
    error_message = "pingtunnel_key must be -1 for auto-generation or an integer between 0 and 2147483647"
  }
}

variable "custom_pre_config" {
  description = "Custom shell commands to run at the start of the startup script. DANGER: This can easily break the setup script"
  type        = string
  default     = ""
}

variable "custom_post_config" {
  description = "Custom shell commands to run at the end of the startup script"
  type        = string
  default     = ""
}

variable "ipsec_vpn_config" {
  description = "Configuration for IPSec/L2TP VPN"
  type = object({
    enable         = bool
    username       = string
    client_ip_pool = string
  })
  default = {
    enable         = true
    username       = ""
    client_ip_pool = "172.31.10.0/24"
  }
}

variable "ipsec_vpn_secrets" {
  description = "Sensitive configuration values for IPSec/L2TP VPN"
  type = object({
    psk      = string
    password = string
  })
  default = {
    psk      = ""
    password = ""
  }
  sensitive = true
}

variable "wireguard_config" {
  description = "Configuration for WireGuard VPN"
  type = object({
    enable             = bool
    port               = number
    client_public_key  = string
    client_ip          = string
    client_allowed_ips = string
  })
  default = {
    enable             = false
    port               = 51820
    client_public_key  = ""
    client_ip          = "172.31.11.2/24"
    client_allowed_ips = "0.0.0.0/0"
  }
  validation {
    condition     = var.wireguard_config.port > 0 && var.wireguard_config.port < 65536
    error_message = "port must be a valid port number between 1 and 65535"
  }
  validation {
    condition     = var.wireguard_config.client_public_key == "" || can(regex("^[A-Za-z0-9+/]{43}=$", var.wireguard_config.client_public_key))
    error_message = "If provided, client_public_key must be a valid base64-encoded public key"
  }
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.wireguard_config.client_ip))
    error_message = "client_ip must be a valid CIDR notation IP address"
  }
  validation {
    condition     = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}/[0-9]{1,2}$", var.wireguard_config.client_allowed_ips))
    error_message = "client_allowed_ips must be a valid CIDR notation IP address range"
  }
}
