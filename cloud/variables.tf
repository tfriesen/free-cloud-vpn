# Module enable/disable flags
variable "enable_aws" {
  description = "Enable AWS module"
  type        = bool
  default     = true
}

variable "enable_azure" {
  description = "Enable Azure module"
  type        = bool
  default     = true
}

variable "enable_google" {
  description = "Enable Google Cloud module"
  type        = bool
  default     = true
}

variable "enable_oracle" {
  description = "Enable Oracle Cloud module"
  type        = bool
  default     = false
}

# Cloudflare Configuration
variable "enable_cloudflare" {
  description = "Enable Cloudflare module"
  type        = bool
  default     = false
}

variable "cloudflare_config" {
  description = "Configuration for Cloudflare integration (excluding the enable flag)"
  type = object({
    domain                     = string
    manage_universal_ssl       = optional(bool, true)
    manage_origin_cert         = optional(bool, true)
    origin_cert_validity_years = optional(number, 15)
    origin_cert_hostnames      = optional(list(string), [])
  })
  default = {
    domain = ""
  }
  validation {
    condition     = var.cloudflare_config.domain == "" || can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,}$", var.cloudflare_config.domain))
    error_message = "If provided, domain must be a valid domain name."
  }
}

variable "ipv6_enabled" {
  description = "Enable IPv6 for providers that support it (currently Oracle)."
  type        = bool
  default     = true
}

variable "tenancy_ocid" {
  description = "The OCID of the Oracle Cloud tenancy (root compartment)"
  type        = string
  default     = null
}

# AWS Configuration
variable "alert_email" {
  description = "Optional email address to receive free tier alerts. If not provided, alerts will not be configured."
  type        = string
  default     = null
  validation {
    condition     = var.alert_email == null || can(regex("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$", var.alert_email))
    error_message = "If provided, alert_email must be a valid email address."
  }
}

# Google Cloud Configuration
variable "gcp_vm_username" {
  description = "Username for the GCP VM instance"
  type        = string
  default     = "free-vpn-user"
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*$", var.gcp_vm_username))
    error_message = "VM username must start with a letter and can only contain lowercase letters, numbers, and hyphens."
  }
}

variable "dns_tunnel_config" {
  description = "Configuration for the DNS tunnel using iodine"
  type = object({
    enable    = optional(bool, true)
    domain    = optional(string, null)
    server_ip = optional(string, "172.31.9.1")
  })
  default = {
    enable = true
    domain = null
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
}

variable "custom_pre_config" {
  description = "Custom shell commands to run at the start of the cloud computer's startup script"
  type        = string
  default     = ""
}

variable "custom_post_config" {
  description = "Custom shell commands to run at the end of the cloud computer's startup script"
  type        = string
  default     = ""
}

variable "enable_pingtunnel" {
  description = "Whether to enable pingtunnel (ICMP tunneling using pingtunnel project)"
  type        = bool
  default     = true
}

variable "pingtunnel_key" {
  description = "Key for pingtunnel authentication (integer between 0-2147483647). If not specified, a random key will be generated"
  type        = number
  default     = -1
  validation {
    condition     = var.pingtunnel_key >= -1 && var.pingtunnel_key <= 2147483647
    error_message = "pingtunnel_key must be an integer between 0 and 2147483647"
  }
}

variable "pingtunnel_aes_key" {
  description = "AES encryption key for pingtunnel. If empty, a random 16-character key will be generated"
  type        = string
  default     = ""
}

variable "https_proxy_password" {
  description = "Password for the HTTPS proxy. If not specified, a random password will be generated"
  type        = string
  default     = ""
  validation {
    condition     = var.https_proxy_password == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{8,}$", var.https_proxy_password))
    error_message = "If provided, https_proxy_password must be at least 8 characters long and contain only letters, numbers, and common special characters."
  }
}

variable "https_proxy_domain" {
  description = "Domain to use for the HTTPS proxy's LetsEncrypt certificate. If not specified, a self-signed certificate will be used. 
    WARNING: If your DNS is not properly sorted, this will likely cause LE to fail. The VM will then fallback to creating a self-signed cert,
    but this won't be reflected in the outputs."
  type        = string
  default     = ""
  validation {
    condition     = var.https_proxy_domain == "" || can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,}$", var.https_proxy_domain))
    error_message = "If provided, https_proxy_domain must be a valid domain name."
  }
}

variable "ipsec_vpn_config" {
  description = "Configuration for IPSec/IKEv2 VPN"
  type = object({
    enable         = optional(bool, true)
    username       = optional(string, "")
    client_ip_pool = optional(string, "172.31.10.0/24")
  })
  default = {
    enable = false
  }
  validation {
    condition     = var.ipsec_vpn_config.username == "" || can(regex("^[a-z][-a-z0-9]*$", var.ipsec_vpn_config.username))
    error_message = "If provided, username must start with a letter and can only contain lowercase letters, numbers, and hyphens."
  }
  validation {
    condition     = can(cidrhost(var.ipsec_vpn_config.client_ip_pool, 0))
    error_message = "client_ip_pool must be a valid CIDR range"
  }
}

variable "ipsec_vpn_secrets" {
  description = "Sensitive configuration values for IPSec/IKEv2 VPN"
  type = object({
    password = optional(string, "")
    psk      = optional(string, "")
  })
  default   = {}
  sensitive = true
  validation {
    condition     = var.ipsec_vpn_secrets.password == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{8,}$", var.ipsec_vpn_secrets.password))
    error_message = "If provided, password must be at least 8 characters long and contain only letters, numbers, and common special characters."
  }
  validation {
    condition     = var.ipsec_vpn_secrets.psk == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{8,}$", var.ipsec_vpn_secrets.psk))
    error_message = "If provided, psk must be at least 8 characters long and contain only letters, numbers, and common special characters."
  }
}

variable "wireguard_config" {
  description = "Configuration for WireGuard VPN"
  type = object({
    enable             = bool
    port               = optional(number, 51820)
    client_public_key  = string
    client_ip          = optional(string, "172.31.11.2/24")
    client_allowed_ips = optional(string, "0.0.0.0/0")
  })
  default = {
    enable            = false
    client_public_key = ""
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

variable "ssh_ports" {
  description = "List of ports for SSH daemon to listen on"
  type        = list(number)
  default     = [22, 80, 8080, 3389, 993, 995, 587, 465, 143, 110, 21, 25]
  validation {
    condition     = length(var.ssh_ports) > 0 && alltrue([for port in var.ssh_ports : port >= 1 && port <= 65535])
    error_message = "ssh_ports must contain at least one port and all ports must be between 1 and 65535"
  }
  validation {
    condition     = !contains(var.ssh_ports, 443) && !contains(var.ssh_ports, 53)
    error_message = "ssh_ports cannot include port 443 (HTTPS) or port 53 (DNS)"
  }
}
