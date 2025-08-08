variable "project_id" {
  description = "The GCP project ID. If not specified, the project ID of the VM will be used."
  default     = ""
  type        = string
}

variable "zone" {
  description = "The zone to deploy the VM in."
  type        = string
  default     = "us-central1-a"
}

variable "network_tier" {
  description = "The network tier for the VM's network interface."
  type        = string
  default     = "STANDARD"
}

# Provider-agnostic variables that are passed through to vm_config module
variable "vm_username" {
  description = "The username for the VM instance"
  type        = string
  default     = "free-vpn-user"
}

variable "ssh_keys" {
  description = "SSH keys for the VM."
  type        = string
  default     = ""
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
}

variable "https_proxy_domain" {
  description = "Domain name for the HTTPS proxy certificate"
  type        = string
  default     = ""
}

variable "https_proxy_password" {
  description = "Password for the HTTPS proxy. If not specified, a random password will be generated"
  type        = string
  default     = ""
}

variable "ipsec_vpn_config" {
  description = "Configuration for the IPSec VPN"
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
  description = "Secrets for the IPSec VPN"
  type = object({
    password = optional(string, "")
    psk      = optional(string, "")
  })
  default   = {}
  sensitive = true
}

variable "wireguard_config" {
  description = "Configuration for WireGuard VPN"
  type = object({
    enable            = bool
    port              = number
    client_public_key = string
    client_ip         = string
  })
  default = {
    enable            = false
    port              = 51820
    client_public_key = ""
    client_ip         = "172.31.11.2/24"
  }
  validation {
    condition     = var.wireguard_config.port >= 1 && var.wireguard_config.port <= 65535
    error_message = "port must be between 1 and 65535"
  }
  validation {
    condition     = var.wireguard_config.client_public_key == "" || can(regex("^[A-Za-z0-9+/]{43}=$", var.wireguard_config.client_public_key))
    error_message = "If provided, client_public_key must be a valid base64-encoded public key"
  }
  validation {
    condition     = var.wireguard_config.client_ip == "" || can(cidrhost(var.wireguard_config.client_ip, 0))
    error_message = "client_ip must be a valid CIDR range"
  }
}

variable "enable_pingtunnel" {
  description = "Enable pingtunnel for ICMP tunneling"
  type        = bool
  default     = true
}

variable "pingtunnel_key" {
  description = "Key for pingtunnel authentication. If -1, a random key will be generated"
  type        = number
  default     = -1
}

variable "pingtunnel_aes_key" {
  description = "AES encryption key for pingtunnel. If empty, a random 16-character key will be generated"
  type        = string
  default     = ""
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
