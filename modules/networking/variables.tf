variable "config" {
  description = "Networking module configuration"
  type = object({
    vpc_cidr             = string
    environment          = string
    availability_zones   = list(string)
    public_subnet_cidrs  = list(string)
    private_subnet_cidrs = list(string)
  })
}
