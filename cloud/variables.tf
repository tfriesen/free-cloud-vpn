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

variable "enable_google" {
  description = "Enable Google Cloud module"
  type        = bool
  default     = true
}
