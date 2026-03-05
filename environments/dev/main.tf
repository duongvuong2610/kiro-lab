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

# Networking Module
module "networking" {
  source = "../../modules/networking"

  config = {
    vpc_cidr             = "10.0.0.0/16"
    environment          = "dev"
    availability_zones   = ["us-east-1a", "us-east-1b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  }
}

# Compute Module
module "compute" {
  source = "../../modules/compute"

  config = {
    cluster_name       = "dev-cluster"
    service_name       = "dev-service"
    task_cpu           = "256"
    task_memory        = "512"
    container_image    = "nginx:latest"
    container_port     = 80
    desired_count      = 2
    vpc_id             = module.networking.vpc_id
    public_subnet_ids  = module.networking.public_subnet_ids
    private_subnet_ids = module.networking.private_subnet_ids
    environment        = "dev"
  }
}

# Database Module
module "database" {
  source = "../../modules/database"

  config = {
    identifier            = "dev-db"
    engine_version        = "14.7"
    instance_class        = "db.t3.micro"
    allocated_storage     = 20
    database_name         = "appdb"
    master_username       = "dbadmin"
    master_password       = "changeme12345" # TODO: Move to Parameter Store or environment variable
    vpc_id                = module.networking.vpc_id
    private_subnet_ids    = module.networking.private_subnet_ids
    ecs_security_group_id = module.compute.task_security_group_id
    environment           = "dev"
  }
}

# Storage Module
module "storage" {
  source = "../../modules/storage"

  config = {
    bucket_name            = "dev-app-storage-${data.aws_caller_identity.current.account_id}"
    environment            = "dev"
    versioning_enabled     = true
    lifecycle_ia_days      = 30
    lifecycle_glacier_days = 90
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
