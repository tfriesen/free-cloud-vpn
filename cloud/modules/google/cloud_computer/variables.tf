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

variable "custom_pre_config" {
  description = "Custom shell commands to run at the start of the startup script"
  type        = string
  default     = ""
}

variable "custom_post_config" {
  description = "Custom shell commands to run at the end of the startup script"
  type        = string
  default     = ""
}
