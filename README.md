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

## Backend Setup Procedures

Terraform requires a remote backend for state management to enable team collaboration and prevent concurrent modifications. This project uses AWS S3 for state storage and DynamoDB for state locking.

### Step 1: Create S3 Bucket for State Storage

Create an S3 bucket to store Terraform state files. Replace `YOUR_ACCOUNT_ID` with your AWS account ID:

```bash
# Set your AWS account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

# Create S3 bucket for Terraform state
aws s3api create-bucket \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --region us-east-1

# Enable versioning on the state bucket
aws s3api put-bucket-versioning \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled

# Enable encryption for the state bucket
aws s3api put-bucket-encryption \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access to the state bucket
aws s3api put-public-access-block \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Step 2: Create DynamoDB Table for State Locking

Create a DynamoDB table to enable state locking and prevent concurrent modifications:

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 3: Verify Backend Resources

Verify that the S3 bucket and DynamoDB table were created successfully:

```bash
# Verify S3 bucket
aws s3api head-bucket --bucket terraform-state-${AWS_ACCOUNT_ID}

# Verify DynamoDB table
aws dynamodb describe-table --table-name terraform-state-lock --query 'Table.TableStatus'
```

### Step 4: Update Backend Configuration

Update the `backend.tf` files in each environment directory (`environments/dev/backend.tf` and `environments/prod/backend.tf`) with your AWS account ID:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-YOUR_ACCOUNT_ID"  # Replace with your account ID
    key            = "dev/terraform.tfstate"            # Use "prod/terraform.tfstate" for prod
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Deploying the Infrastructure

### Initial Setup (One-Time)

Before deploying to any environment, initialize Terraform at the root level:

```bash
# Initialize Terraform (downloads providers, enables validation/formatting)
terraform init
```

This allows you to run `terraform fmt` and `terraform validate` from the root directory across all modules without needing to initialize each module separately.

### Development Environment

1. **Navigate to the dev environment directory:**

```bash
cd environments/dev
```

2. **Initialize Terraform:**

```bash
terraform init
```

3. **Review the execution plan:**

```bash
terraform plan
```

4. **Apply the configuration:**

```bash
terraform apply
```

5. **Note the outputs:**

After successful deployment, Terraform will output important information like the ALB DNS name, RDS endpoint, and S3 bucket name.

### Production Environment

Follow the same steps as above, but use the `environments/prod` directory:

```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

## Application Deployment

### Example Application

This project includes a simple example web application in the `example-app/` directory that demonstrates the infrastructure. The application:

- Displays "Welcome to CMC TS" on the root endpoint
- Provides a `/health` endpoint for ALB health checks
- Is containerized and ready to deploy to ECS

**Quick Start with Example App:**

```bash
# Navigate to the example app directory
cd example-app

# Build the Docker image
docker build -t cmc-ts-app:latest .

# Push to Docker Hub or ECR (see example-app/README.md for detailed instructions)
```

For complete documentation on building, pushing, and deploying the example application, see [example-app/README.md](example-app/README.md).

### Prerequisites

Before deploying the infrastructure, you need to:

1. **Create Parameter Store secrets** for your application:

```bash
# Database password
aws ssm put-parameter \
  --name "/dev/app/db_password" \
  --value "YOUR_SECURE_PASSWORD" \
  --type SecureString \
  --region us-east-1

# Add other secrets as needed
aws ssm put-parameter \
  --name "/dev/app/api_key" \
  --value "YOUR_API_KEY" \
  --type SecureString \
  --region us-east-1
```

2. **Build and push your container image** to Docker Hub or Amazon ECR:

```bash
# Build your application container
docker build -t your-app:latest .

# Tag and push to ECR (example)
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com
docker tag your-app:latest ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/your-app:latest
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.us-east-1.amazonaws.com/your-app:latest
```

3. **Update the container image** in `environments/dev/terraform.tfvars`:

```hcl
container_image = "YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/your-app:latest"
```

### Container Requirements

Your application container must:

- Expose a port (default: 80)
- Implement a `/health` endpoint that returns HTTP 200 when healthy
- Read secrets from environment variables (automatically injected from Parameter Store)

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

## Troubleshooting

### State Lock Issues

If Terraform reports a state lock error:

```bash
# Force unlock (use with caution)
terraform force-unlock LOCK_ID
```

### Backend Initialization Errors

If `terraform init` fails with backend errors:

1. Verify S3 bucket and DynamoDB table exist
2. Check AWS credentials have necessary permissions
3. Ensure bucket name in `backend.tf` matches your actual bucket

### Resource Creation Failures

If `terraform apply` fails:

1. Review error messages for specific resource issues
2. Check AWS service quotas and limits
3. Verify IAM permissions are sufficient
4. Review CloudWatch logs for ECS task failures

## Cleanup

To destroy all infrastructure resources:

```bash
cd environments/dev
terraform destroy

cd ../prod
terraform destroy
```

**Warning**: This will permanently delete all resources. Ensure you have backups of any important data.

## Contributing

1. Create a feature branch
2. Make changes and ensure `terraform fmt` and `terraform validate` pass
3. Submit a pull request
4. CI/CD pipeline will automatically validate changes

## License

This project is provided as-is for educational and development purposes.
# CI/CD Test
