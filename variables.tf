variable "tfe_token" {
  description = "HCP Terraform / Terraform Enterprise API token for accessing private registries"
  type        = string
  sensitive   = true
  default     = ""
}

variable "tfe_address" {
  description = "HCP Terraform / Terraform Enterprise address"
  type        = string
  default     = "https://app.terraform.io"

  validation {
    condition     = can(regex("^https://", var.tfe_address))
    error_message = "TFE address must start with https://"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production"
  }
}

variable "owner" {
  description = "Owner or team responsible for the resources"
  type        = string
  default     = "platform-team"
}
