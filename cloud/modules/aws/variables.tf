variable "alert_email" {
  description = "Optional email address to receive Lambda free tier alerts. If not provided, alerts will not be configured."
  type        = string
  default     = null
  validation {
    condition     = var.alert_email == null || can(regex("^[\\w-\\.]+@([\\w-]+\\.)+[\\w-]{2,4}$", var.alert_email))
    error_message = "If provided, alert_email must be a valid email address."
  }
}
