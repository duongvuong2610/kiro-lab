# Root-level Terraform configuration
# This file enables terraform fmt and terraform validate to work
# across all modules without needing to run terraform init in each module
# CI/CD: Workflow triggers on changes to .tf files

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Dummy module calls for validation purposes only
# These ensure 'terraform validate' checks all module code
# Actual infrastructure deployment happens in environments/dev and environments/prod

# Note: These modules are not meant to be applied from root
# They exist solely to enable validation of module code

module "networking_validation" {
  source = "./modules/networking"
  count  = 0 # Never actually create resources

  config = {
    vpc_cidr             = "10.0.0.0/16"
    environment          = "validation"
    availability_zones   = ["us-east-1a", "us-east-1b"]
    public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
    private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]
  }
}

module "compute_validation" {
  source = "./modules/compute"
  count  = 0 # Never actually create resources

  config = {
    cluster_name       = "validation-cluster"
    service_name       = "validation-service"
    task_cpu           = "256"
    task_memory        = "512"
    container_image    = "nginx:latest"
    container_port     = 80
    desired_count      = 2
    vpc_id             = "vpc-12345678"
    public_subnet_ids  = ["subnet-12345678", "subnet-87654321"]
    private_subnet_ids = ["subnet-11111111", "subnet-22222222"]
    environment        = "validation"
  }
}

module "database_validation" {
  source = "./modules/database"
  count  = 0 # Never actually create resources

  config = {
    identifier            = "validation-db"
    engine_version        = "14.7"
    instance_class        = "db.t3.micro"
    allocated_storage     = 20
    database_name         = "validationdb"
    master_username       = "dbadmin"
    master_password       = "ValidPassword123!"
    vpc_id                = "vpc-12345678"
    private_subnet_ids    = ["subnet-11111111", "subnet-22222222"]
    ecs_security_group_id = "sg-12345678"
    environment           = "validation"
  }
}

module "storage_validation" {
  source = "./modules/storage"
  count  = 0 # Never actually create resources

  config = {
    bucket_name            = "validation-bucket-12345"
    environment            = "validation"
    versioning_enabled     = true
    lifecycle_ia_days      = 30
    lifecycle_glacier_days = 90
  }
}
