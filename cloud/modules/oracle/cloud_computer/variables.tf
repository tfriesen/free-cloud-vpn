
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

# Pass-through variables for vm_config module
variable "ssh_keys" { type = string }
variable "custom_pre_config" { type = string }
variable "custom_post_config" { type = string }
variable "dns_tunnel_config" { type = any }
variable "dns_tunnel_password" { type = string }
variable "https_proxy_domain" { type = string }
variable "https_proxy_password" { type = string }
variable "ipsec_vpn_config" { type = any }
variable "ipsec_vpn_secrets" { type = any }
variable "wireguard_config" { type = any }
variable "enable_pingtunnel" { type = bool }
variable "pingtunnel_key" { type = any }
variable "ssh_ports" { type = list(number) }
