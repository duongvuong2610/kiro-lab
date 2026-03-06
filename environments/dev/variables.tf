variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDR blocks"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of private subnet CIDR blocks"
  type        = list(string)
}

variable "task_cpu" {
  description = "ECS task CPU units"
  type        = string
}

variable "task_memory" {
  description = "ECS task memory in MB"
  type        = string
}

variable "container_image" {
  description = "Docker container image URI"
  type        = string
}

variable "container_port" {
  description = "Container port"
  type        = number
}

variable "desired_count" {
  description = "Desired number of ECS tasks"
  type        = number
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
}

variable "database_name" {
  description = "Database name"
  type        = string
}

variable "db_master_username" {
  description = "Database master username"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable S3 versioning"
  type        = bool
}

variable "lifecycle_ia_days" {
  description = "Days until transition to Infrequent Access"
  type        = number
}

variable "lifecycle_glacier_days" {
  description = "Days until transition to Glacier"
  type        = number
}
