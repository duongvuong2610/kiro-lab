variable "config" {
  description = "Database module configuration"
  type = object({
    identifier            = string
    engine_version        = string
    instance_class        = string
    allocated_storage     = number
    database_name         = string
    master_username       = string
    master_password       = string
    vpc_id                = string
    private_subnet_ids    = list(string)
    ecs_security_group_id = string
    environment           = string
  })

  validation {
    condition     = length(var.config.private_subnet_ids) >= 2
    error_message = "At least 2 private subnets are required for DB subnet group."
  }

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9-]*$", var.config.identifier))
    error_message = "Database identifier must start with a letter and contain only alphanumeric characters and hyphens."
  }

  validation {
    condition     = length(var.config.master_password) >= 8
    error_message = "Master password must be at least 8 characters long."
  }
}
