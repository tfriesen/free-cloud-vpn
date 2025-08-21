
variable "compartment_id" {
  description = "The OCID of the compartment to create resources in."
  type        = string
}

variable "availability_domain" {
  description = "The availability domain to launch the instance in."
  type        = string
}

variable "subnet_id" {
  description = "The OCID of the subnet to launch the instance in."
  type        = string
}

variable "image_id" {
  description = "The OCID of the image to use for the instance (e.g., Oracle Linux Free Tier image)."
  type        = string
}

variable "shape" {
  description = "The shape (instance type) for the VM (e.g., VM.Standard.A1.Flex for ARM, VM.Standard.E2.1.Micro for x86 free tier)."
  type        = string
}

variable "ocpus" {
  description = "The number of OCPUs for the instance."
  type        = number
  default     = 4
}

variable "memory_in_gbs" {
  description = "The amount of memory in GBs for the instance."
  type        = number
  default     = 24
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

variable "ipv6_enabled" {
  description = "Enable IPv6 assignment on the instance primary VNIC."
  type        = bool
  default     = true
}

# Pass-through variables for vm_config module
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
}
