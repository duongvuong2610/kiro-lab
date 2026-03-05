variable "config" {
  description = "Storage module configuration"
  type = object({
    bucket_name            = string
    environment            = string
    versioning_enabled     = bool
    lifecycle_ia_days      = number
    lifecycle_glacier_days = number
  })

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.config.bucket_name))
    error_message = "Bucket name must start and end with lowercase letter or number, and contain only lowercase letters, numbers, and hyphens."
  }

  validation {
    condition     = length(var.config.bucket_name) >= 3 && length(var.config.bucket_name) <= 63
    error_message = "Bucket name must be between 3 and 63 characters long."
  }

  validation {
    condition     = var.config.lifecycle_ia_days > 0 && var.config.lifecycle_glacier_days > var.config.lifecycle_ia_days
    error_message = "Lifecycle glacier days must be greater than lifecycle IA days, and both must be positive."
  }
}
