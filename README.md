# AWS 3-Tier Terraform Infrastructure

This project provides a complete AWS 3-tier containerized application infrastructure using Terraform. The infrastructure includes networking (VPC), compute (ECS Fargate), database (RDS PostgreSQL), and storage (S3) components with multi-environment support (dev/prod).

## Architecture Overview

- **Presentation Tier**: Application Load Balancer (ALB) in public subnets
- **Application Tier**: ECS Fargate containers in private subnets
- **Data Tier**: RDS PostgreSQL and S3 storage in private subnets

## Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5.0
- [AWS CLI](https://aws.amazon.com/cli/) configured with appropriate credentials
- AWS account with sufficient permissions to create VPC, ECS, RDS, S3, IAM resources
- [Docker](https://www.docker.com/) (for building and pushing container images)

## Project Structure

```
aws-terraform-infrastructure/
├── modules/
│   ├── networking/     # VPC, subnets, gateways, routing
│   ├── compute/        # ECS Fargate, ALB, auto-scaling
│   ├── database/       # RDS PostgreSQL
│   └── storage/        # S3 with lifecycle policies
├── environments/
│   ├── dev/           # Development environment config
│   └── prod/          # Production environment config
├── example-app/       # Example containerized application
├── .github/workflows/ # CI/CD pipelines
├── .kiro/            # Kiro IDE integration
├── docs/             # Architecture diagrams and documentation
├── scripts/          # Helper scripts (backend setup, etc.)
├── main.tf           # Root-level config for validation/formatting
└── versions.tf       # Terraform version constraints
```

## Module Variable Structure

All modules use object-based variable configuration for cleaner interfaces:

```hcl
# Example: Networking module
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
```

## Quick Start

For complete deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

### Backend Setup

The Terraform backend is already configured with:
- S3 Bucket: `terraform-state-471112857175`
- DynamoDB Table: `terraform-state-lock`
- Region: `us-east-1`

For detailed backend setup instructions, see [docs/BACKEND_SETUP.md](docs/BACKEND_SETUP.md).

## Deploying the Infrastructure

For complete step-by-step deployment instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

### Quick Deploy

```bash
# 1. Build and push Docker image (MUST use linux/amd64 architecture)
cd example-app
docker buildx build --platform linux/amd64 -t cmc-ts-app:latest .
# ... push to ECR (see DEPLOYMENT.md)

# 2. Create Parameter Store secrets
aws ssm put-parameter --name "/dev/app/db_password" --value "PASSWORD" --type SecureString --region us-east-1 --profile kiro-lab

# 3. Deploy infrastructure
cd environments/dev
terraform init
terraform plan
terraform apply

# 4. Force ECS deployment
aws ecs update-service --cluster dev-cluster --service dev-service --force-new-deployment --region us-east-1 --profile kiro-lab
```

## Application Deployment

This project includes an example Node.js web application in `example-app/` that demonstrates the infrastructure.

**CRITICAL:** Docker images MUST be built for `linux/amd64` architecture (ECS Fargate requirement):

```bash
cd example-app
docker buildx build --platform linux/amd64 -t cmc-ts-app:latest .
```

For complete instructions, see [DEPLOYMENT.md](DEPLOYMENT.md) and [example-app/README.md](example-app/README.md).

## Cost Optimization

### Stopping Resources to Reduce Costs

For development environments, you can stop resources during non-working hours to reduce costs:

**Stop RDS Instance:**

```bash
aws rds stop-db-instance --db-instance-identifier dev-db --region us-east-1
```

**Start RDS Instance:**

```bash
aws rds start-db-instance --db-instance-identifier dev-db --region us-east-1
```

**Scale Down ECS Service:**

```bash
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-service \
  --desired-count 0 \
  --region us-east-1
```

**Scale Up ECS Service:**

```bash
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-service \
  --desired-count 2 \
  --region us-east-1
```

### Cost-Effective Configurations

The dev environment uses cost-optimized settings:

- RDS: `db.t3.micro` instance (suitable for development)
- ECS: 256 CPU units, 512 MB memory (minimal for testing)
- S3: Lifecycle policies automatically transition old objects to cheaper storage classes

## Security Considerations

This infrastructure implements AWS security best practices:

- **Encryption at Rest**: Enabled for RDS and S3
- **Network Isolation**: Databases and application servers in private subnets
- **Least Privilege**: Security groups allow only required traffic
- **Secrets Management**: Credentials stored in AWS Parameter Store, not hardcoded
- **Public Access**: S3 buckets block all public access
- **State Security**: Terraform state encrypted and versioned

## CI/CD Pipeline

The project includes a GitHub Actions workflow that automatically validates Terraform changes on pull requests:

- Runs `terraform fmt -check` to ensure consistent formatting
- Runs `terraform validate` to check syntax
- Generates `terraform plan` and posts results as PR comment
- Blocks merge if validation fails

To use the CI/CD pipeline, add AWS credentials to GitHub Secrets:

- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

## Kiro IDE Integration

This project includes Kiro IDE integration for accelerated development:

- **Agent Hooks**: Automatic validation on `.tf` file save
- **Steering Files**: Enforced coding standards and security rules
- **MCP Servers**: Terraform and GitHub tool integration
- **Specs**: Requirements and design documents for AI-assisted coding

## Validation and Formatting

With the root-level Terraform configuration, you can validate and format all modules from the project root:

```bash
# One-time: Initialize to install modules
terraform init

# Format all Terraform files recursively
terraform fmt -recursive

# Validate all module configurations (validates all 4 modules)
terraform validate

# Check formatting without making changes
terraform fmt -check -recursive
```

The root `main.tf` includes dummy module calls with `count = 0` that enable validation of all module code without actually creating resources. This ensures `terraform validate` checks networking, compute, database, and storage modules.

## Documentation

- **[DEPLOYMENT.md](DEPLOYMENT.md)** - Complete deployment guide with step-by-step instructions
- **[README.md](README.md)** - Project overview and architecture (this file)
- **[docs/BACKEND_SETUP.md](docs/BACKEND_SETUP.md)** - Detailed backend setup and troubleshooting
- **[docs/AWS_RESOURCES.md](docs/AWS_RESOURCES.md)** - List of all AWS resources created
- **[docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md)** - Project structure and module documentation
- **[example-app/README.md](example-app/README.md)** - Example application documentation

## Cleanup

To destroy all infrastructure:

```bash
cd environments/dev
terraform destroy
```

For complete cleanup instructions, see [DEPLOYMENT.md](DEPLOYMENT.md).

## Contributing

1. Create a feature branch
2. Make changes and ensure `terraform fmt` and `terraform validate` pass
3. Submit a pull request
4. CI/CD pipeline will automatically validate changes

## License

This project is provided as-is for educational and development purposes.
