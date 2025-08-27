variable "vm_username" {
  description = "The username for the VM instance"
  type        = string
  default     = "free-vpn-user"
}

variable "cloud_provider" {
  description = "The cloud provider (google, oracle, etc.)"
  type        = string
  default     = "google"
}

variable "arch" {
  description = "The CPU architecture (x86_64 or arm64)"
  type        = string
  default     = "x86_64"
}

variable "ssh_keys" {
  description = "SSH keys for the VM."
  type        = string
  default     = ""
}

variable "custom_pre_config" {
  description = "Custom pre-config script to run on the VM"
  type        = string
  default     = ""
}

variable "custom_post_config" {
  description = "Custom post-config script to run on the VM"
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

variable "https_proxy_config" {
  description = "Configuration for the HTTPS proxy (BasicAuth, cert, etc.)"
  type = object({
    username          = optional(string, "clouduser")
    domain            = optional(string, "")
    external_cert_pem = optional(string, "")
  })
  default = {}
  validation {
    condition     = var.https_proxy_config.domain == null || var.https_proxy_config.domain == "" || can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,}$", var.https_proxy_config.domain))
    error_message = "If provided, domain must be a valid domain name."
  }
}

variable "https_proxy_secrets" {
  description = "Sensitive configuration for the HTTPS proxy (password, private key)"
  type = object({
    password         = optional(string, "")
    external_key_pem = optional(string, "")
  })
  default   = {}
  sensitive = true
  validation {
    condition     = var.https_proxy_secrets.password == null || var.https_proxy_secrets.password == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{8,}$", var.https_proxy_secrets.password))
    error_message = "If provided, password must be at least 8 characters long and contain only letters, numbers, and common special characters."
  }
}

variable "ipsec_vpn_config" {
  description = "Configuration for the IPSec VPN"
  type = object({
    enable         = optional(bool, true)
    username       = optional(string, "")
    client_ip_pool = optional(string, "192.168.42.0/24")
  })
  default = {
    enable = true
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
    enable            = optional(bool, true)
    port              = optional(string, "51820")
    client_ip         = optional(string, "10.0.0.2/24")
    client_public_key = optional(string, "")
  })
  default = {
    enable = true
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
    condition = alltrue([
      for port in var.ssh_ports : port >= 1 && port <= 65535
    ])
    error_message = "All SSH ports must be valid port numbers (1-65535)."
  }
  validation {
    condition     = !contains(var.ssh_ports, 443) && !contains(var.ssh_ports, 53)
    error_message = "SSH ports cannot include 443 (HTTPS) or 53 (DNS) as these are reserved."
  }
}
