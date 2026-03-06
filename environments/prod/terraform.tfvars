# Prod Environment Configuration
# This file contains environment-specific values for the prod environment
# Values are optimized for production workloads with higher availability and performance

# Environment identifier
environment = "prod"

# AWS Region
aws_region = "us-east-1"

# Networking Configuration
vpc_cidr             = "10.1.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.1.1.0/24", "10.1.2.0/24"]
private_subnet_cidrs = ["10.1.3.0/24", "10.1.4.0/24"]

# Compute Configuration (production-grade)
task_cpu        = "1024"         # 1 vCPU (4x dev)
task_memory     = "2048"         # 2 GB (4x dev)
container_image = "471112857175.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app:latest" # Replace with your application image
container_port  = 80
desired_count   = 3 # Higher count for production

# Database Configuration (production-grade instance)
db_instance_class  = "db.t3.small" # Larger than dev (db.t3.micro)
database_name      = "appdb"
db_master_username = "dbadmin"
# Note: db_master_password should be set via environment variable or AWS Parameter Store
# Example: export TF_VAR_db_master_password="your-secure-password"

# Storage Configuration
versioning_enabled     = true
lifecycle_ia_days      = 90  # Longer retention for prod
lifecycle_glacier_days = 180 # Longer retention for prod
