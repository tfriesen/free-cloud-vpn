variable "zone" {
  description = "The zone to deploy the VM in."
  type        = string
  default     = "us-central1-a"
}

variable "ssh_keys" {
  description = "SSH keys for the VM."
  type        = string
  default     = ""
}

variable "network_tier" {
  description = "The network tier for the VM's network interface."
  type        = string
  default     = "STANDARD"
}

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

variable "enable_icmp_tunnel" {
  description = "Whether to enable ICMP tunneling"
  type        = bool
  default     = false
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
  description = "Sensitive configuration values for IPSec/L2TP VPN"
  type = object({
    psk      = string
    password = string
  })
  default = {
    psk      = ""
    password = ""
  }
  validation {
    condition     = var.ipsec_vpn_secrets.psk == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{16,}$", var.ipsec_vpn_secrets.psk))
    error_message = "If provided, psk must be at least 16 characters long and contain only letters, numbers, and common special characters."
  }
  validation {
    condition     = var.ipsec_vpn_secrets.password == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{8,}$", var.ipsec_vpn_secrets.password))
    error_message = "If provided, password must be at least 8 characters long and contain only letters, numbers, and common special characters."
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
