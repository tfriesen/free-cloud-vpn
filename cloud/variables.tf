variable "enable_azure" {
  description = "Enable Azure module"
  type        = bool
  default     = true
}

variable "enable_aws" {
  description = "Enable AWS module"
  type        = bool
  default     = true
}

variable "aws_alert_email" {
  description = "Optional email address to receive AWS Lambda free tier alerts. If not provided, alerts will not be configured."
  type        = string
  default     = null
  validation {
    condition     = var.aws_alert_email == null || can(regex("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$", var.aws_alert_email))
    error_message = "If provided, aws_alert_email must be a valid email address."
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

variable "enable_google" {
  description = "Enable Google Cloud module"
  type        = bool
  default     = true
}
