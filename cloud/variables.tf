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
variable "enable_dns_tunnel" {
  description = "Whether to enable the DNS tunnel using iodine"
  type        = bool
  default     = true
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

variable "gcp_vm_username" {
  description = "Username for the GCP VM instance"
  type        = string
  default     = "free-vpn-user"
  validation {
    condition     = can(regex("^[a-z][-a-z0-9]*$", var.gcp_vm_username))
    error_message = "VM username must start with a letter and can only contain lowercase letters, numbers, and hyphens."
  }
}

variable "dns_tunnel_password" {
  description = "Password for the DNS tunnel. If not specified, a random password will be generated"
  type        = string
  default     = ""
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
  validation {
    condition     = var.https_proxy_password == "" || can(regex("^[A-Za-z0-9!@#$%^&*()_+\\-=\\[\\]{};:'\",./?]{8,}$", var.https_proxy_password))
    error_message = "If provided, https_proxy_password must be at least 8 characters long and contain only letters, numbers, and common special characters."
  }
}

variable "https_proxy_domain" {
  description = "Domain to use for the HTTPS proxy's LetsEncrypt certificate. If not specified, a self-signed certificate will be used"
  type        = string
  default     = ""
  validation {
    condition     = var.https_proxy_domain == "" || can(regex("^([a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,}$", var.https_proxy_domain))
    error_message = "If provided, https_proxy_domain must be a valid domain name."
  }
}
