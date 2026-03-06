terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"

  default_tags {
    tags = {
      Environment = "dev"
      ManagedBy   = "terraform"
      Project     = "aws-terraform-infrastructure"
    }
  }
}

# Data sources for dynamic lookups
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Fetch database password from Parameter Store
data "aws_ssm_parameter" "db_password" {
  name = "/${var.environment}/app/db_password"
}

# Networking Module
module "networking" {
  source = "../../modules/networking"

  config = {
    vpc_cidr             = var.vpc_cidr
    environment          = var.environment
    availability_zones   = var.availability_zones
    public_subnet_cidrs  = var.public_subnet_cidrs
    private_subnet_cidrs = var.private_subnet_cidrs
  }
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  config = {
    cluster_name       = "dev-cluster"
    service_name       = "dev-service"
    task_cpu           = var.task_cpu
    task_memory        = var.task_memory
    container_image    = var.container_image
    container_port     = var.container_port
    desired_count      = var.desired_count
    vpc_id             = module.networking.vpc_id
    public_subnet_ids  = module.networking.public_subnet_ids
    private_subnet_ids = module.networking.private_subnet_ids
    environment        = var.environment
  }
}

# Database Module
module "database" {
  source = "../../modules/database"

  config = {
    identifier            = "${var.environment}-db"
    engine_version        = "14.15"
    instance_class        = var.db_instance_class
    allocated_storage     = 20
    database_name         = var.database_name
    master_username       = var.db_master_username
    master_password       = data.aws_ssm_parameter.db_password.value
    vpc_id                = module.networking.vpc_id
    private_subnet_ids    = module.networking.private_subnet_ids
    ecs_security_group_id = module.compute.task_security_group_id
    environment           = var.environment
  }
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  config = {
    bucket_name            = "${var.environment}-app-storage-${data.aws_caller_identity.current.account_id}"
    environment            = var.environment
    versioning_enabled     = var.versioning_enabled
    lifecycle_ia_days      = var.lifecycle_ia_days
    lifecycle_glacier_days = var.lifecycle_glacier_days
  }
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "Application Load Balancer DNS name"
  value       = module.compute.alb_dns_name
}

output "database_endpoint" {
  description = "Database endpoint"
  value       = module.database.endpoint
  sensitive   = true
}

output "storage_bucket_name" {
  description = "S3 bucket name"
  value       = module.storage.bucket_name
}
