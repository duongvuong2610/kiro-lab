variable "config" {
  description = "Compute module configuration"
  type = object({
    cluster_name       = string
    service_name       = string
    task_cpu           = string
    task_memory        = string
    container_image    = string
    container_port     = number
    desired_count      = number
    vpc_id             = string
    public_subnet_ids  = list(string)
    private_subnet_ids = list(string)
    environment        = string
  })
}
