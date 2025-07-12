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

variable "enable_google" {
  description = "Enable Google Cloud module"
  type        = bool
  default     = true
}
