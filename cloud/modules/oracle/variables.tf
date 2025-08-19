variable "tenancy_ocid" {
  description = "The OCID of the tenancy (root compartment)"
  type        = string
}

variable "compartment_name" {
  description = "Name for the compartment to create for free tier resources."
  type        = string
  default     = "free-tier-vpn"
}

variable "shape" {
  description = "The shape (instance type) for the VM. Default is VM.Standard.A1.Flex for ARM free tier (4 cores, 24GB RAM)."
  type        = string
  default     = "VM.Standard.A1.Flex"
}

variable "display_name" {
  description = "Display name for the instance."
  type        = string
  default     = "free-tier-vm"
}

variable "vm_username" {
  description = "The username for the VM instance"
  type        = string
  default     = "free-vpn-user"
}

variable "ssh_keys" {
  description = "SSH public keys to add to the VM. If empty, a key will be generated."
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
  sensitive   = true
}

variable "alert_email" {
  description = "Optional email address to receive cloud provider free tier alerts"
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

variable "ipsec_vpn_config" {
  description = "Configuration for IPSec/IKEv2 VPN"
  type = object({
    enable         = optional(bool, true)
    client_ip_pool = optional(string, "10.10.10.0/24")
  })
  default = {
    enable = true
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
    condition     = alltrue([for port in var.ssh_ports : port >= 1 && port <= 65535])
    error_message = "All SSH ports must be valid port numbers (1-65535)."
  }
  validation {
    condition     = !contains(var.ssh_ports, 443) && !contains(var.ssh_ports, 53)
    error_message = "SSH ports cannot include 443 (HTTPS) or 53 (DNS) as these are reserved."
  }
}

variable "ipv6_enabled" {
  description = "Enable IPv6 for the Oracle VCN, subnet, route table, and instance VNIC."
  type        = bool
  default     = true
}
