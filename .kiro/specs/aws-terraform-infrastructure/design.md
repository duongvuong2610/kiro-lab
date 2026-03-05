# Design Document: AWS Terraform Infrastructure

## Overview

This design document describes a comprehensive AWS 3-tier containerized application infrastructure provisioning system built with Terraform. The system provides reusable, modular infrastructure-as-code components that enable teams to deploy secure, scalable, and cost-optimized cloud environments.

The infrastructure follows AWS best practices for multi-tier application architecture:
- **Presentation Tier**: Application Load Balancer (ALB) in public subnets
- **Application Tier**: ECS Fargate containers in private subnets
- **Data Tier**: RDS PostgreSQL and S3 storage in private subnets

The design emphasizes:
- **Modularity**: Four independent Terraform modules (networking, compute, database, storage) that can be composed for different use cases
- **Multi-Environment Support**: Separate configurations for dev and prod environments with environment-specific parameters
- **Security**: Encryption at rest, private subnet isolation, least-privilege security groups, secrets management via Parameter Store
- **Automation**: CI/CD pipeline for validation and deployment, Kiro IDE integration for accelerated development
- **Cost Optimization**: Lifecycle policies, right-sized instances, and documented procedures for resource management

The system integrates deeply with Kiro IDE through specs, agent hooks, steering files, and MCP servers to provide AI-assisted infrastructure development with automatic validation and enforced coding standards.

## Architecture

### High-Level Architecture

The infrastructure consists of four core Terraform modules orchestrated through environment-specific configurations:

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
├── .github/workflows/ # CI/CD pipelines
└── .kiro/            # Kiro IDE integration
```

### Network Architecture

The networking module creates a VPC with multi-AZ redundancy:

```
VPC (10.0.0.0/16)
├── Availability Zone A
│   ├── Public Subnet A (10.0.1.0/24)
│   │   ├── Internet Gateway
│   │   ├── NAT Gateway
│   │   └── ALB (public-facing)
│   └── Private Subnet A (10.0.3.0/24)
│       ├── ECS Tasks
│       └── RDS Primary
└── Availability Zone B
    ├── Public Subnet B (10.0.2.0/24)
    │   └── ALB (public-facing)
    └── Private Subnet B (10.0.4.0/24)
        └── ECS Tasks
```

Traffic flow:
1. Internet → Internet Gateway → ALB (public subnets)
2. ALB → ECS Tasks (private subnets)
3. ECS Tasks → RDS (private subnets)
4. ECS Tasks → Internet (via NAT Gateway for outbound)

### Compute Architecture

The compute module provisions containerized workloads using ECS Fargate:

```
Application Load Balancer
├── Target Group (health check: /health)
│   └── ECS Service
│       ├── Task Definition
│       │   ├── Container Definition
│       │   ├── Secrets from Parameter Store
│       │   └── CloudWatch Logs
│       ├── Desired Count: 2
│       ├── Deployment Circuit Breaker
│       └── Auto Scaling Policy (target: 70% CPU)
```

The ALB distributes traffic across ECS tasks running in multiple availability zones. Auto-scaling adjusts task count based on CPU utilization to handle variable load.

### Data Architecture

Data persistence is handled by two modules:

**Database Module (RDS PostgreSQL)**:
- Single-AZ deployment (suitable for dev/test)
- Encryption at rest enabled
- Placed in private subnets
- Security group allows traffic only from ECS tasks
- Connection details exported for application configuration

**Storage Module (S3)**:
- Versioning enabled for data protection
- Lifecycle policies for cost optimization:
  - 30 days → Infrequent Access
  - 90 days → Glacier
- Public access blocked
- Encryption enabled

### Security Architecture

Security controls are implemented at multiple layers:

**Network Security**:
- Public/private subnet isolation
- Security groups with least-privilege rules
- No direct internet access from private subnets (NAT Gateway for outbound only)

**Data Security**:
- Encryption at rest for RDS and S3
- Secrets stored in AWS Parameter Store (not hardcoded)
- No wildcard IAM permissions

**Access Control**:
- ALB → ECS: Port 80/443 only
- ECS → RDS: PostgreSQL port only from ECS security group
- S3: Private access only

### CI/CD Architecture

GitHub Actions workflows automate infrastructure validation and deployment:

```
Pull Request → GitHub Actions
├── terraform fmt -check
├── terraform validate
├── terraform plan
└── Post plan as PR comment
```

The pipeline ensures all infrastructure changes are validated before merge, preventing configuration errors from reaching production.

### Kiro IDE Integration Architecture

The system integrates with Kiro IDE through multiple mechanisms:

**Specs**: Requirements and design documents in `.kiro/specs/` guide AI-assisted code generation

**Agent Hooks**: Automatic validation on `.tf` file save:
- `terraform validate` checks syntax
- `terraform fmt` enforces formatting

**Steering Files**: Enforced coding standards in `.kiro/steering/`:
- Naming conventions
- Tagging strategy
- Security requirements (encryption, private subnets, no wildcards)

**MCP Servers**: Tool integration via `.kiro/mcp.json`:
- `terraform-mcp-server`: Execute Terraform commands
- `github`: Interact with GitHub API

This integration accelerates development by providing immediate feedback, enforcing standards, and enabling AI-assisted infrastructure coding.

## Components and Interfaces

### Networking Module

**Location**: `modules/networking/`

**Purpose**: Provisions VPC, subnets, gateways, and routing infrastructure

**Input Variables** (`variables.tf`):
```hcl
variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod)"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}
```

**Outputs** (`outputs.tf`):
```hcl
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = aws_subnet.private[*].id
}

output "nat_gateway_id" {
  description = "ID of NAT Gateway"
  value       = aws_nat_gateway.main.id
}

output "internet_gateway_id" {
  description = "ID of Internet Gateway"
  value       = aws_internet_gateway.main.id
}
```

**Resources Created**:
- 1 VPC
- 2 public subnets (across 2 AZs)
- 2 private subnets (across 2 AZs)
- 1 Internet Gateway
- 1 NAT Gateway (in public subnet)
- 2 route tables (public and private)
- Route table associations

**Interface Contract**:
- Consumers must provide VPC CIDR and subnet CIDRs
- Module guarantees multi-AZ deployment (2 AZs)
- Public subnets have internet access via Internet Gateway
- Private subnets have outbound internet access via NAT Gateway

### Compute Module

**Location**: `modules/compute/`

**Purpose**: Provisions ECS Fargate cluster, tasks, services, ALB, and auto-scaling

**Input Variables** (`variables.tf`):
```hcl
variable "cluster_name" {
  description = "Name of ECS cluster"
  type        = string
}

variable "service_name" {
  description = "Name of ECS service"
  type        = string
}

variable "task_cpu" {
  description = "CPU units for task (256, 512, 1024, etc.)"
  type        = string
}

variable "task_memory" {
  description = "Memory for task in MB"
  type        = string
}

variable "container_image" {
  description = "Docker image for container"
  type        = string
}

variable "container_port" {
  description = "Port exposed by container"
  type        = number
}

variable "desired_count" {
  description = "Desired number of tasks"
  type        = number
  default     = 2
}

variable "vpc_id" {
  description = "VPC ID from networking module"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for ECS tasks"
  type        = list(string)
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

**Outputs** (`outputs.tf`):
```hcl
output "cluster_id" {
  description = "ID of ECS cluster"
  value       = aws_ecs_cluster.main.id
}

output "service_name" {
  description = "Name of ECS service"
  value       = aws_ecs_service.main.name
}

output "alb_dns_name" {
  description = "DNS name of ALB"
  value       = aws_lb.main.dns_name
}

output "alb_arn" {
  description = "ARN of ALB"
  value       = aws_lb.main.arn
}

output "task_security_group_id" {
  description = "Security group ID for ECS tasks"
  value       = aws_security_group.ecs_tasks.id
}
```

**Resources Created**:
- 1 ECS Fargate cluster (Container Insights enabled)
- 1 Task Definition (with Parameter Store secret references)
- 1 ECS Service (desired_count=2, circuit breaker enabled)
- 1 Application Load Balancer
- 1 Target Group (health check: /health)
- 1 ALB Listener (port 80)
- 2 Security Groups (ALB and ECS tasks)
- 1 Auto Scaling Target
- 1 Auto Scaling Policy (target tracking, 70% CPU)
- IAM roles for task execution and task role

**Interface Contract**:
- Requires VPC and subnet IDs from networking module
- Pulls secrets from Parameter Store (not hardcoded)
- Health check endpoint must be `/health`
- Auto-scales between min and max task count based on CPU
- ALB provides public endpoint for application access

### Database Module

**Location**: `modules/database/`

**Purpose**: Provisions RDS PostgreSQL instance with security controls

**Input Variables** (`variables.tf`):
```hcl
variable "identifier" {
  description = "Database identifier"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "14.7"
}

variable "instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 20
}

variable "database_name" {
  description = "Name of database to create"
  type        = string
}

variable "master_username" {
  description = "Master username"
  type        = string
}

variable "master_password" {
  description = "Master password"
  type        = string
  sensitive   = true
}

variable "vpc_id" {
  description = "VPC ID from networking module"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for RDS"
  type        = list(string)
}

variable "ecs_security_group_id" {
  description = "Security group ID of ECS tasks"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}
```

**Outputs** (`outputs.tf`):
```hcl
output "endpoint" {
  description = "Database endpoint"
  value       = aws_db_instance.main.endpoint
}

output "address" {
  description = "Database address"
  value       = aws_db_instance.main.address
}

output "port" {
  description = "Database port"
  value       = aws_db_instance.main.port
}

output "database_name" {
  description = "Database name"
  value       = aws_db_instance.main.db_name
}

output "security_group_id" {
  description = "Security group ID for database"
  value       = aws_security_group.rds.id
}
```

**Resources Created**:
- 1 RDS PostgreSQL instance (Single-AZ)
- 1 DB Subnet Group (private subnets)
- 1 Security Group (allows traffic only from ECS tasks)

**Interface Contract**:
- Requires VPC and private subnet IDs from networking module
- Requires ECS task security group ID from compute module
- Encryption at rest enabled by default
- Placed only in private subnets
- Security group allows PostgreSQL port (5432) only from ECS tasks

### Storage Module

**Location**: `modules/storage/`

**Purpose**: Provisions S3 bucket with lifecycle policies and security controls

**Input Variables** (`variables.tf`):
```hcl
variable "bucket_name" {
  description = "Name of S3 bucket"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "versioning_enabled" {
  description = "Enable versioning"
  type        = bool
  default     = true
}

variable "lifecycle_ia_days" {
  description = "Days until transition to Infrequent Access"
  type        = number
  default     = 30
}

variable "lifecycle_glacier_days" {
  description = "Days until transition to Glacier"
  type        = number
  default     = 90
}
```

**Outputs** (`outputs.tf`):
```hcl
output "bucket_name" {
  description = "Name of S3 bucket"
  value       = aws_s3_bucket.main.id
}

output "bucket_arn" {
  description = "ARN of S3 bucket"
  value       = aws_s3_bucket.main.arn
}

output "bucket_domain_name" {
  description = "Domain name of S3 bucket"
  value       = aws_s3_bucket.main.bucket_domain_name
}
```

**Resources Created**:
- 1 S3 bucket
- Versioning configuration
- Lifecycle policy (IA after 30 days, Glacier after 90 days)
- Public access block (all public access blocked)
- Server-side encryption configuration

**Interface Contract**:
- Bucket name must be globally unique
- All public access blocked by default
- Encryption enabled by default
- Lifecycle policies configurable via variables

### Environment Configuration

**Location**: `environments/{dev,prod}/`

**Purpose**: Environment-specific Terraform configurations that compose modules

**Files per Environment**:

`main.tf`:
```hcl
# Provider configuration
provider "aws" {
  region = var.aws_region
}

# Networking module
module "networking" {
  source = "../../modules/networking"
  
  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  availability_zones   = var.availability_zones
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

# Compute module
module "compute" {
  source = "../../modules/compute"
  
  cluster_name        = "${var.environment}-cluster"
  service_name        = "${var.environment}-service"
  task_cpu            = var.task_cpu
  task_memory         = var.task_memory
  container_image     = var.container_image
  container_port      = var.container_port
  desired_count       = var.desired_count
  vpc_id              = module.networking.vpc_id
  public_subnet_ids   = module.networking.public_subnet_ids
  private_subnet_ids  = module.networking.private_subnet_ids
  environment         = var.environment
}

# Database module
module "database" {
  source = "../../modules/database"
  
  identifier              = "${var.environment}-db"
  instance_class          = var.db_instance_class
  database_name           = var.database_name
  master_username         = var.db_master_username
  master_password         = var.db_master_password
  vpc_id                  = module.networking.vpc_id
  private_subnet_ids      = module.networking.private_subnet_ids
  ecs_security_group_id   = module.compute.task_security_group_id
  environment             = var.environment
}

# Storage module
module "storage" {
  source = "../../modules/storage"
  
  bucket_name = "${var.environment}-app-storage-${data.aws_caller_identity.current.account_id}"
  environment = var.environment
}
```

`terraform.tfvars`:
```hcl
# Environment-specific values
environment = "dev"  # or "prod"
aws_region  = "us-east-1"

# Networking
vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.3.0/24", "10.0.4.0/24"]

# Compute
task_cpu        = "256"
task_memory     = "512"
container_image = "nginx:latest"  # Replace with actual app image
container_port  = 80
desired_count   = 2

# Database
db_instance_class  = "db.t3.micro"  # Smaller for dev, larger for prod
database_name      = "appdb"
db_master_username = "dbadmin"
# db_master_password should be set via environment variable or secrets manager
```

`backend.tf`:
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-{account-id}"
    key            = "{environment}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

**Interface Contract**:
- Each environment is independent
- State files are isolated per environment
- Environment-specific values in `terraform.tfvars`
- Modules are referenced via relative paths

### CI/CD Pipeline

**Location**: `.github/workflows/terraform-plan.yml`

**Purpose**: Automated validation of Terraform changes on pull requests

**Workflow Structure**:
```yaml
name: Terraform Plan

on:
  pull_request:
    branches:
      - main
    paths:
      - '**.tf'
      - '**.tfvars'

jobs:
  terraform-plan:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0
      
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      
      - name: Terraform Init
        run: terraform init
        working-directory: environments/dev
      
      - name: Terraform Validate
        run: terraform validate
        working-directory: environments/dev
      
      - name: Terraform Plan
        run: terraform plan -out=tfplan
        working-directory: environments/dev
        env:
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      
      - name: Post Plan to PR
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const plan = fs.readFileSync('environments/dev/tfplan', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Terraform Plan\n\`\`\`\n${plan}\n\`\`\``
            });
```

**Interface Contract**:
- Triggers on PR to main branch
- Validates formatting, syntax, and generates plan
- Posts plan results as PR comment
- Fails workflow if any validation step fails
- Requires AWS credentials in GitHub secrets

### Kiro Integration Components

#### Spec Files

**Location**: `.kiro/specs/networking-module/`, `.kiro/specs/compute-module/`, etc.

**Purpose**: Define requirements and design for each module to guide AI-assisted code generation

**Structure**:
- `requirements.md`: User stories and acceptance criteria
- `design.md`: Architecture and implementation details
- `tasks.md`: Implementation tasks

#### Agent Hook

**Location**: `.kiro/hooks/terraform-validate.js`

**Purpose**: Automatic validation on `.tf` file save

**Functionality**:
```javascript
// Pseudo-code structure
module.exports = {
  trigger: {
    filePattern: "**/*.tf",
    event: "onSave"
  },
  actions: [
    {
      name: "Format Terraform",
      command: "terraform fmt",
      workingDirectory: "{{fileDirectory}}"
    },
    {
      name: "Validate Terraform",
      command: "terraform validate",
      workingDirectory: "{{fileDirectory}}"
    }
  ],
  onError: {
    displayInline: true,
    severity: "error"
  }
};
```

**Interface Contract**:
- Runs automatically on `.tf` file save
- Executes `terraform fmt` and `terraform validate`
- Displays errors inline in editor
- No manual intervention required

#### Steering File

**Location**: `.kiro/steering/terraform-standards.md`

**Purpose**: Enforce coding standards and security requirements

**Content**:
```markdown
# Terraform Coding Standards

## Naming Conventions
- Resources: `{resource_type}_{environment}_{purpose}`
- Variables: snake_case
- Outputs: snake_case
- Modules: kebab-case directories

## Tagging Strategy
All resources must include:
- Environment: dev/prod
- ManagedBy: terraform
- Project: project-name

## Security Requirements
- MUST enable encryption for all data storage (RDS, S3)
- MUST place databases in private subnets
- MUST NOT use wildcard (*) in IAM policies
- MUST retrieve secrets from Parameter Store
- MUST block public access to S3 buckets
- MUST use least-privilege security group rules

## Best Practices
- Use variables for all configurable values
- Document all variables with descriptions
- Export useful outputs for module consumers
- Use data sources for dynamic lookups
- Enable versioning for state backends
```

**Interface Contract**:
- Enforced during Kiro agent code generation
- Agent validates generated code against these rules
- Violations trigger warnings or prevent code generation

#### MCP Configuration

**Location**: `.kiro/mcp.json`

**Purpose**: Configure Model Context Protocol servers for tool integration

**Content**:
```json
{
  "mcpServers": {
    "terraform": {
      "command": "terraform-mcp-server",
      "args": [],
      "env": {}
    },
    "github": {
      "command": "mcp-server-github",
      "args": [],
      "env": {
        "GITHUB_TOKEN": "${GITHUB_TOKEN}"
      }
    }
  }
}
```

**Interface Contract**:
- Enables Kiro to execute Terraform commands
- Enables Kiro to interact with GitHub API
- Requires environment variables for authentication

## Data Models

### Terraform State Structure

The Terraform state file maintains the current infrastructure state. Key components:

**VPC State**:
```json
{
  "vpc_id": "vpc-xxxxx",
  "cidr_block": "10.0.0.0/16",
  "enable_dns_hostnames": true,
  "enable_dns_support": true
}
```

**Subnet State**:
```json
{
  "public_subnets": [
    {
      "id": "subnet-xxxxx",
      "cidr_block": "10.0.1.0/24",
      "availability_zone": "us-east-1a"
    },
    {
      "id": "subnet-yyyyy",
      "cidr_block": "10.0.2.0/24",
      "availability_zone": "us-east-1b"
    }
  ],
  "private_subnets": [
    {
      "id": "subnet-zzzzz",
      "cidr_block": "10.0.3.0/24",
      "availability_zone": "us-east-1a"
    },
    {
      "id": "subnet-aaaaa",
      "cidr_block": "10.0.4.0/24",
      "availability_zone": "us-east-1b"
    }
  ]
}
```

**ECS State**:
```json
{
  "cluster": {
    "id": "arn:aws:ecs:region:account:cluster/name",
    "name": "dev-cluster"
  },
  "service": {
    "id": "arn:aws:ecs:region:account:service/cluster/service",
    "name": "dev-service",
    "desired_count": 2,
    "running_count": 2
  },
  "task_definition": {
    "arn": "arn:aws:ecs:region:account:task-definition/name:1",
    "family": "dev-task",
    "cpu": "256",
    "memory": "512"
  }
}
```

**RDS State**:
```json
{
  "db_instance": {
    "id": "dev-db",
    "endpoint": "dev-db.xxxxx.us-east-1.rds.amazonaws.com:5432",
    "engine": "postgres",
    "engine_version": "14.7",
    "instance_class": "db.t3.micro",
    "storage_encrypted": true
  }
}
```

**S3 State**:
```json
{
  "bucket": {
    "id": "dev-app-storage-123456789",
    "arn": "arn:aws:s3:::dev-app-storage-123456789",
    "versioning": {
      "enabled": true
    },
    "lifecycle_rules": [
      {
        "id": "transition-to-ia",
        "status": "Enabled",
        "transitions": [
          {
            "days": 30,
            "storage_class": "STANDARD_IA"
          },
          {
            "days": 90,
            "storage_class": "GLACIER"
          }
        ]
      }
    ]
  }
}
```

### Module Variable Schema

Each module defines its input contract through variables:

**Type Constraints**:
- `string`: Single text value
- `number`: Numeric value
- `bool`: Boolean value
- `list(string)`: Array of strings
- `map(string)`: Key-value pairs
- `object({...})`: Structured object with defined fields

**Validation Rules**:
- CIDR blocks must be valid IPv4 CIDR notation
- Instance types must match AWS instance type patterns
- Availability zones must exist in the target region
- Subnet CIDRs must be within VPC CIDR range

### Resource Tagging Schema

All resources are tagged with consistent metadata:

```hcl
tags = {
  Name        = "${var.environment}-${resource_type}"
  Environment = var.environment
  ManagedBy   = "terraform"
  Project     = "aws-terraform-infrastructure"
  CostCenter  = var.cost_center
}
```

This enables:
- Cost allocation by environment
- Resource filtering and searching
- Compliance tracking
- Automated resource management

### Security Group Rule Schema

Security group rules follow a structured format:

```hcl
# Ingress rule
{
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  source_security_group_id = aws_security_group.alb.id
  description       = "Allow HTTP from ALB"
}

# Egress rule
{
  type        = "egress"
  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]
  description = "Allow all outbound"
}
```

Rules enforce least-privilege access:
- ALB → ECS: Only HTTP/HTTPS ports
- ECS → RDS: Only PostgreSQL port (5432)
- ECS → Internet: Via NAT Gateway for outbound only

### Parameter Store Schema

Secrets are stored in AWS Systems Manager Parameter Store:

```
/dev/app/db_password          (SecureString)
/dev/app/api_key              (SecureString)
/dev/app/jwt_secret           (SecureString)
```

ECS task definitions reference these parameters:

```hcl
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "/dev/app/db_password"
  }
]
```

This ensures:
- Secrets are never hardcoded in Terraform
- Secrets are encrypted at rest
- Access is controlled via IAM policies
- Secrets can be rotated without code changes


## Correctness Properties

A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.

For infrastructure-as-code, properties verify that Terraform configurations produce the expected AWS resources with correct configurations, security controls, and relationships. These properties can be validated through Terraform plan output analysis, state file inspection, and configuration file parsing.

### Property 1: VPC Creation with Configurable CIDR

For any valid CIDR block provided to the networking module, applying the module should create a VPC resource with that exact CIDR block.

**Validates: Requirements 1.1**

### Property 2: Multi-AZ Public Subnet Distribution

For any networking module configuration, the created infrastructure should contain exactly 2 public subnets distributed across 2 different availability zones.

**Validates: Requirements 1.2**

### Property 3: Multi-AZ Private Subnet Distribution

For any networking module configuration, the created infrastructure should contain exactly 2 private subnets distributed across 2 different availability zones.

**Validates: Requirements 1.3**

### Property 4: Internet Gateway Attachment

For any networking module configuration, the created infrastructure should include an Internet Gateway that is attached to the VPC.

**Validates: Requirements 1.4**

### Property 5: NAT Gateway in Public Subnet

For any networking module configuration, the created infrastructure should include a NAT Gateway placed in one of the public subnets.

**Validates: Requirements 1.5**

### Property 6: Route Table Configuration

For any networking module configuration, public subnets should have routes to the Internet Gateway and private subnets should have routes to the NAT Gateway.

**Validates: Requirements 1.6**

### Property 7: Module Output Completeness

For any infrastructure module (networking, compute, database, storage), the module should define outputs that expose resource identifiers needed by consuming modules or applications.

**Validates: Requirements 1.7, 3.6, 4.6**

### Property 8: ECS Cluster with Container Insights

For any compute module configuration, the created ECS Fargate cluster should have Container Insights enabled.

**Validates: Requirements 2.1**

### Property 9: Task Definition with Parameter Store Secrets

For any compute module configuration, the ECS task definition should reference AWS Parameter Store for secrets rather than containing hardcoded values.

**Validates: Requirements 2.2, 15.3**

### Property 10: ECS Service Desired Count

For any compute module configuration, the ECS service should be created with desired_count set to 2.

**Validates: Requirements 2.3**

### Property 11: Deployment Circuit Breaker

For any compute module configuration, the ECS service should have deployment circuit breaker enabled.

**Validates: Requirements 2.4**

### Property 12: ALB with Target Group

For any compute module configuration, an Application Load Balancer should be created with a target group configured to route traffic to the ECS service.

**Validates: Requirements 2.5**

### Property 13: Health Check Endpoint Configuration

For any compute module configuration, the ALB target group should be configured with a health check endpoint at /health.

**Validates: Requirements 2.6**

### Property 14: Auto-Scaling Policy Configuration

For any compute module configuration, an auto-scaling policy should be created with target tracking based on 70% CPU utilization.

**Validates: Requirements 2.7**

### Property 15: Security Group Rules for ALB to ECS

For any compute module configuration, security group rules should allow traffic from the ALB security group to the ECS task security group on the application port.

**Validates: Requirements 2.8**

### Property 16: RDS PostgreSQL Configuration

For any database module configuration, an RDS instance should be created with PostgreSQL engine in Single-AZ configuration.

**Validates: Requirements 3.1**

### Property 17: RDS Encryption at Rest

For any database module configuration, the RDS instance should have encryption at rest enabled (storage_encrypted = true).

**Validates: Requirements 3.2**

### Property 18: RDS in Private Subnets

For any database module configuration, the RDS instance should be placed in private subnets only (via DB subnet group).

**Validates: Requirements 3.3, 15.1**

### Property 19: RDS Security Group Restriction

For any database module configuration, the RDS security group should allow inbound traffic only from the ECS task security group on the PostgreSQL port (5432).

**Validates: Requirements 3.4**

### Property 20: Development-Appropriate Instance Types

For any database module configuration in a development environment, the RDS instance type should be from the t3 or t4g family suitable for development workloads.

**Validates: Requirements 3.5, 14.1**

### Property 21: S3 Versioning Enabled

For any storage module configuration, the S3 bucket should have versioning enabled.

**Validates: Requirements 4.1**

### Property 22: S3 Lifecycle Policy for Infrequent Access

For any storage module configuration, the S3 bucket should have a lifecycle policy that transitions objects to Infrequent Access storage class after 30 days.

**Validates: Requirements 4.2**

### Property 23: S3 Lifecycle Policy for Glacier

For any storage module configuration, the S3 bucket should have a lifecycle policy that transitions objects to Glacier storage class after 90 days.

**Validates: Requirements 4.3**

### Property 24: S3 Public Access Block

For any storage module configuration, the S3 bucket should have all public access blocked (all four public access block settings set to true).

**Validates: Requirements 4.4, 15.2**

### Property 25: S3 Encryption Enabled

For any storage module configuration, the S3 bucket should have server-side encryption enabled.

**Validates: Requirements 4.5**

### Property 26: Environment Configuration Files

For any environment directory (dev or prod), the directory should contain main.tf, terraform.tfvars, and backend.tf files.

**Validates: Requirements 5.3, 5.4, 5.5**

### Property 27: Module References in Environment

For any environment configuration, the main.tf file should reference all four infrastructure modules (networking, compute, database, storage).

**Validates: Requirements 5.6**

### Property 28: S3 Backend Configuration

For any environment configuration, the backend.tf file should configure an S3 backend for storing Terraform state files.

**Validates: Requirements 6.1**

### Property 29: DynamoDB State Locking

For any environment configuration, the backend.tf file should configure a DynamoDB table for state locking.

**Validates: Requirements 6.2**

### Property 30: State Bucket Versioning

For any Terraform state backend S3 bucket, versioning should be enabled.

**Validates: Requirements 6.3**

### Property 31: State File Encryption

For any environment configuration, the backend.tf file should enable encryption for state files (encrypt = true).

**Validates: Requirements 6.4**

### Property 32: Backend Configuration per Environment

For any environment directory (dev or prod), a backend.tf file should exist with environment-specific state configuration.

**Validates: Requirements 6.5**

### Property 33: CI/CD Workflow Trigger

For any terraform-plan.yml workflow file, the workflow should be configured to trigger on pull requests targeting the main branch.

**Validates: Requirements 7.1**

### Property 34: CI/CD Validation Steps

For any terraform-plan.yml workflow file, the workflow should include steps for terraform fmt -check, terraform validate, terraform plan, and posting plan results to the pull request.

**Validates: Requirements 7.2, 7.3, 7.4, 7.5**

### Property 35: Spec File Completeness

For any infrastructure module spec directory, the directory should contain requirements.md and design.md files with content defining the module's requirements and design decisions.

**Validates: Requirements 8.2, 8.3**

### Property 36: Agent Hook Validation Commands

For any Kiro agent hook configuration for Terraform files, the hook should execute both terraform validate and terraform fmt when a .tf file is saved.

**Validates: Requirements 9.2, 9.3**

### Property 37: Agent Hook Error Display

For any Kiro agent hook configuration, the hook should be configured to display error messages when validation fails.

**Validates: Requirements 9.4**

### Property 38: Agent Hook Automatic Execution

For any Kiro agent hook configuration for Terraform files, the hook should be configured to run automatically on file save without manual intervention.

**Validates: Requirements 9.5**

### Property 39: Steering File Security Rules

For any Kiro steering file, the file should define rules that prohibit wildcard permissions in IAM policies, require encryption for data storage resources, and require private subnets for database resources.

**Validates: Requirements 10.4, 10.5, 10.6**

### Property 40: Steering File Standards

For any Kiro steering file, the file should define naming conventions for AWS resources and tagging strategy for all resources.

**Validates: Requirements 10.2, 10.3**

### Property 41: MCP Server Configuration

For any Kiro MCP configuration file, the file should configure both terraform-mcp-server and github MCP servers.

**Validates: Requirements 11.2, 11.3**

### Property 42: Container Image Configuration

For any compute module task definition, the container definition should include an image property referencing a container image from Docker Hub or ECR.

**Validates: Requirements 13.1, 13.3**

### Property 43: IAM Policy Wildcard Prohibition

For any IAM policy document in the infrastructure, the policy should not contain wildcard (*) permissions for actions or resources.

**Validates: Requirements 15.6**

### Property 44: Project Structure Completeness

For any complete infrastructure project, the following directory structure should exist:
- modules/networking/
- modules/compute/
- modules/database/
- modules/storage/
- environments/dev/
- environments/prod/
- .github/workflows/
- .kiro/specs/
- .kiro/hooks/
- .kiro/steering/

And the following files should exist:
- modules/*/variables.tf
- modules/*/outputs.tf
- .github/workflows/terraform-plan.yml
- .kiro/mcp.json

**Validates: Requirements 1.8, 1.9, 2.9, 2.10, 3.7, 3.8, 4.7, 4.8, 5.1, 5.2, 7.7, 9.1, 10.1, 11.1**

## Error Handling

### Terraform Validation Errors

**Error Type**: Invalid Terraform syntax or configuration

**Detection**: 
- CI/CD pipeline runs `terraform validate` on every pull request
- Kiro agent hook runs `terraform validate` on every `.tf` file save
- Developers receive immediate feedback

**Handling**:
- CI/CD workflow fails and blocks merge
- Error messages displayed in PR comments
- Kiro IDE displays inline errors in editor
- Developer must fix errors before proceeding

**Recovery**: Developer corrects syntax errors and re-saves file or pushes corrected code

### Terraform Formatting Errors

**Error Type**: Code not formatted according to Terraform standards

**Detection**:
- CI/CD pipeline runs `terraform fmt -check` on every pull request
- Kiro agent hook runs `terraform fmt` on every `.tf` file save

**Handling**:
- CI/CD workflow fails if formatting is incorrect
- Kiro agent hook automatically formats code on save
- Consistent formatting enforced across team

**Recovery**: Automatic via `terraform fmt` or manual correction

### AWS Resource Creation Failures

**Error Type**: AWS API errors during `terraform apply` (e.g., insufficient permissions, quota limits, invalid configurations)

**Detection**:
- Terraform apply command returns non-zero exit code
- Error messages from AWS API

**Handling**:
- Terraform stops execution and reports error
- No partial state changes (Terraform is atomic per resource)
- State file remains consistent
- Error messages indicate which resource failed and why

**Recovery**:
- Review error message to identify root cause
- Correct configuration or AWS account settings
- Re-run `terraform apply`
- If state is corrupted, use `terraform state` commands to repair

### State Lock Conflicts

**Error Type**: Multiple users attempting to modify infrastructure simultaneously

**Detection**:
- DynamoDB state lock table prevents concurrent modifications
- Terraform reports "state locked" error

**Handling**:
- Second user's operation is blocked
- Error message indicates who holds the lock
- User must wait for lock to be released

**Recovery**:
- Wait for first operation to complete
- If lock is stuck (process crashed), manually release lock using `terraform force-unlock`

### Missing Required Variables

**Error Type**: Required Terraform variables not provided

**Detection**:
- Terraform init/plan/apply fails with "variable not defined" error

**Handling**:
- Terraform refuses to proceed
- Error message indicates which variables are missing

**Recovery**:
- Add missing variables to `terraform.tfvars`
- Or provide via command line: `terraform apply -var="variable=value"`
- Or set environment variables: `TF_VAR_variable=value`

### Invalid CIDR Blocks

**Error Type**: Overlapping or invalid CIDR blocks for VPC/subnets

**Detection**:
- Terraform validation catches invalid CIDR format
- AWS API rejects overlapping CIDRs during apply

**Handling**:
- Terraform reports validation error
- Clear error message about CIDR conflict

**Recovery**:
- Review VPC and subnet CIDR allocations
- Ensure subnets are within VPC CIDR range
- Ensure subnets don't overlap
- Correct `terraform.tfvars` and re-apply

### Security Group Rule Conflicts

**Error Type**: Conflicting or overly permissive security group rules

**Detection**:
- Kiro steering file enforcement during code generation
- Manual code review
- AWS Config rules (if configured)

**Handling**:
- Kiro agent warns about violations of security standards
- Code review process catches issues
- Terraform applies rules as configured (no automatic validation)

**Recovery**:
- Review security group rules against least-privilege principle
- Correct rules to be more restrictive
- Re-apply configuration

### Secrets Not Found in Parameter Store

**Error Type**: ECS task definition references secrets that don't exist in Parameter Store

**Detection**:
- ECS task fails to start
- CloudWatch logs show "secret not found" errors

**Handling**:
- ECS service deployment fails
- Tasks remain in PENDING state
- Deployment circuit breaker may roll back

**Recovery**:
- Create missing secrets in AWS Parameter Store
- Ensure IAM task execution role has permission to read secrets
- ECS will automatically retry task launch

### Cost Overruns

**Error Type**: Infrastructure costs exceed budget

**Detection**:
- AWS Cost Explorer alerts
- Manual monitoring of AWS billing

**Handling**:
- No automatic handling (requires human decision)
- Document procedures for stopping resources

**Recovery**:
- Stop RDS instances during non-working hours
- Reduce ECS task desired count
- Delete unused resources
- Review and optimize instance types

### Module Dependency Errors

**Error Type**: Module references incorrect outputs or missing dependencies

**Detection**:
- Terraform plan fails with "output not found" or "resource not found" errors

**Handling**:
- Terraform refuses to generate plan
- Error message indicates missing reference

**Recovery**:
- Verify module outputs are correctly defined
- Ensure modules are applied in correct order (Terraform handles this automatically via dependency graph)
- Check that module source paths are correct

## Testing Strategy

### Overview

The infrastructure testing strategy employs a dual approach combining unit tests for specific scenarios and property-based tests for comprehensive validation across all valid inputs. This ensures both concrete correctness (specific examples work) and general correctness (all inputs work).

### Unit Testing

Unit tests validate specific infrastructure configurations and edge cases using Terraform testing frameworks.

**Tools**:
- **Terratest** (Go-based testing framework)
- **terraform test** (native Terraform testing, v1.6+)
- **Checkov** (static analysis for security and compliance)

**Unit Test Focus Areas**:

1. **Specific Environment Configurations**
   - Test dev environment with small instance types
   - Test prod environment with production-grade configurations
   - Verify environment-specific variable values

2. **Edge Cases**
   - Minimum viable configuration (smallest instance types, minimal resources)
   - Maximum configuration (largest supported instance types)
   - Single availability zone fallback scenarios

3. **Integration Points**
   - Module outputs correctly consumed by dependent modules
   - Security group rules allow required traffic
   - IAM roles have necessary permissions

4. **Error Conditions**
   - Invalid CIDR blocks rejected
   - Missing required variables cause clear errors
   - Overlapping subnet CIDRs detected

**Example Unit Test** (using Terratest):
```go
func TestNetworkingModuleCreatesVPC(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../modules/networking",
        Vars: map[string]interface{}{
            "vpc_cidr": "10.0.0.0/16",
            "environment": "test",
            "availability_zones": []string{"us-east-1a", "us-east-1b"},
            "public_subnet_cidrs": []string{"10.0.1.0/24", "10.0.2.0/24"},
            "private_subnet_cidrs": []string{"10.0.3.0/24", "10.0.4.0/24"},
        },
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    vpcId := terraform.Output(t, terraformOptions, "vpc_id")
    assert.NotEmpty(t, vpcId)
}
```

### Property-Based Testing

Property-based tests validate universal properties across many generated inputs using randomized testing.

**Tools**:
- **Terratest with property generators** (custom Go code)
- **Hypothesis** (Python, for Terraform JSON parsing)
- **fast-check** (JavaScript, for configuration validation)

**Property Test Configuration**:
- Minimum 100 iterations per property test
- Each test tagged with reference to design document property
- Tag format: `Feature: aws-terraform-infrastructure, Property {number}: {property_text}`

**Property Test Focus Areas**:

1. **Resource Creation Properties**
   - For any valid CIDR, VPC is created with that CIDR (Property 1)
   - For any configuration, exactly 2 public and 2 private subnets exist (Properties 2, 3)
   - For any module, required outputs are defined (Property 7)

2. **Security Properties**
   - For any configuration, RDS is in private subnets (Property 18)
   - For any configuration, S3 public access is blocked (Property 24)
   - For any IAM policy, no wildcard permissions exist (Property 43)

3. **Configuration Properties**
   - For any environment, all required files exist (Property 44)
   - For any module, variables.tf and outputs.tf exist (Property 44)
   - For any backend config, encryption is enabled (Property 31)

**Example Property Test** (using Terratest with generators):
```go
func TestProperty1_VPCCreationWithConfigurableCIDR(t *testing.T) {
    // Feature: aws-terraform-infrastructure, Property 1: VPC Creation with Configurable CIDR
    
    for i := 0; i < 100; i++ {
        // Generate random valid CIDR block
        cidr := generateRandomCIDR()
        
        terraformOptions := &terraform.Options{
            TerraformDir: "../modules/networking",
            Vars: map[string]interface{}{
                "vpc_cidr": cidr,
                "environment": "test",
                "availability_zones": []string{"us-east-1a", "us-east-1b"},
                "public_subnet_cidrs": generateSubnetCIDRs(cidr, 2),
                "private_subnet_cidrs": generateSubnetCIDRs(cidr, 2),
            },
        }
        
        defer terraform.Destroy(t, terraformOptions)
        terraform.InitAndApply(t, terraformOptions)
        
        // Verify VPC has the specified CIDR
        vpcCIDR := getVPCCIDR(t, terraformOptions)
        assert.Equal(t, cidr, vpcCIDR)
    }
}
```

### Static Analysis Testing

Static analysis validates infrastructure code without deployment.

**Tools**:
- **tflint**: Terraform linting for syntax and best practices
- **Checkov**: Security and compliance scanning
- **terraform-compliance**: BDD-style compliance testing
- **tfsec**: Security-focused static analysis

**Static Analysis Focus**:
- Security vulnerabilities (unencrypted resources, public access)
- Compliance violations (missing tags, incorrect naming)
- Best practice violations (hardcoded values, missing descriptions)
- Cost optimization opportunities

**Example Static Analysis** (using Checkov):
```bash
# Run security scan on all Terraform files
checkov -d . --framework terraform

# Expected checks:
# - CKV_AWS_16: Ensure RDS database has encryption at rest enabled
# - CKV_AWS_19: Ensure S3 bucket has server-side encryption enabled
# - CKV_AWS_21: Ensure S3 bucket has versioning enabled
# - CKV_AWS_54: Ensure S3 bucket has block public access enabled
```

### Integration Testing

Integration tests validate end-to-end infrastructure deployment and connectivity.

**Approach**:
1. Deploy complete environment (all modules)
2. Verify resource connectivity
3. Test application deployment
4. Validate security controls
5. Tear down environment

**Integration Test Scenarios**:
- Deploy dev environment and verify ALB endpoint is accessible
- Deploy application container and verify health check passes
- Verify ECS tasks can connect to RDS database
- Verify ECS tasks can write to S3 bucket
- Verify private subnet resources cannot be accessed from internet

**Example Integration Test**:
```go
func TestCompleteInfrastructureDeployment(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../environments/dev",
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Get ALB DNS name
    albDNS := terraform.Output(t, terraformOptions, "alb_dns_name")
    
    // Verify ALB is accessible
    http_helper.HttpGetWithRetry(t, fmt.Sprintf("http://%s", albDNS), nil, 200, "Welcome", 30, 5*time.Second)
    
    // Verify RDS is NOT publicly accessible
    rdsEndpoint := terraform.Output(t, terraformOptions, "rds_endpoint")
    assert.False(t, isPubliclyAccessible(rdsEndpoint))
}
```

### CI/CD Pipeline Testing

The CI/CD pipeline provides continuous validation of infrastructure changes.

**Pipeline Stages**:
1. **Format Check**: `terraform fmt -check` ensures consistent formatting
2. **Validation**: `terraform validate` checks syntax and configuration
3. **Security Scan**: Checkov/tfsec scan for security issues
4. **Plan Generation**: `terraform plan` generates execution plan
5. **Plan Review**: Plan posted to PR for human review
6. **Unit Tests**: Terratest unit tests run on PR
7. **Integration Tests**: Full deployment tests run on merge to main (optional)

**Test Execution Strategy**:
- Format, validation, and security scans run on every PR (fast, no AWS resources)
- Unit tests run on every PR (may create temporary AWS resources)
- Integration tests run on merge to main or on-demand (expensive, full deployment)
- Property tests run nightly or weekly (time-consuming, many iterations)

### Test Coverage Goals

**Target Coverage**:
- 100% of modules have unit tests for basic functionality
- 100% of correctness properties have property-based tests
- 100% of security requirements validated by static analysis
- 100% of integration points tested in integration tests

**Coverage Tracking**:
- Track which requirements have corresponding tests
- Track which properties have been implemented as property tests
- Use test tags to map tests to requirements and properties

### Testing Best Practices

1. **Isolation**: Each test should create and destroy its own resources
2. **Idempotency**: Tests should be repeatable with same results
3. **Speed**: Prefer static analysis and validation over full deployments
4. **Cost**: Minimize AWS resource creation in tests (use small instance types, short-lived resources)
5. **Cleanup**: Always destroy resources after tests (use defer in Go, try/finally in Python)
6. **Parallelization**: Run independent tests in parallel to reduce execution time
7. **Tagging**: Tag all test resources for easy identification and cleanup

### Manual Testing Procedures

Some aspects require manual validation:

1. **Kiro IDE Integration**
   - Manually verify agent hooks trigger on file save
   - Verify steering file rules are enforced during code generation
   - Verify MCP servers enable Terraform and GitHub commands

2. **Cost Optimization**
   - Manually verify procedures for stopping/starting resources
   - Monitor AWS billing to confirm cost controls are effective

3. **Architecture Diagrams**
   - Manually verify generated diagrams accurately represent infrastructure
   - Verify diagrams are updated when infrastructure changes

4. **Documentation**
   - Manually review documentation for completeness and accuracy
   - Verify documentation matches actual implementation
