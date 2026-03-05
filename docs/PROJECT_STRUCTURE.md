# Project Structure Documentation

This document describes the directory structure and organization of the AWS Terraform Infrastructure project.

## Root Directory Structure

```
aws-terraform-infrastructure/
├── modules/              # Reusable Terraform modules
├── environments/         # Environment-specific configurations
├── .github/             # GitHub Actions workflows
├── .kiro/               # Kiro IDE integration files
├── scripts/             # Utility scripts
├── docs/                # Documentation
├── main.tf              # Root config with module validation
├── .terraform.lock.hcl  # Provider version lock file
├── README.md            # Main project documentation
└── .gitignore          # Git ignore patterns
```

## Modules Directory

The `modules/` directory contains reusable Terraform modules that define infrastructure components. Each module uses object-based variable configuration for cleaner interfaces.

```
modules/
├── networking/          # VPC, subnets, gateways, routing
│   ├── main.tf         # Main resource definitions
│   ├── variables.tf    # Single config object variable
│   └── outputs.tf      # Output values
├── compute/            # ECS Fargate, ALB, auto-scaling
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── database/           # RDS PostgreSQL
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
└── storage/            # S3 with lifecycle policies
    ├── main.tf
    ├── variables.tf
    └── outputs.tf
```

### Module Design Principles

- **Single Responsibility**: Each module manages one logical infrastructure component
- **Object-Based Variables**: All modules use a single `config` object variable
- **Reusability**: Modules can be used across multiple environments
- **Configurability**: All environment-specific values are exposed as object properties
- **Outputs**: Modules export resource identifiers for use by other modules
- **Documentation**: Each variable and output includes a description

### Module Variable Pattern

All modules follow this pattern:

```hcl
variable "config" {
  description = "Module configuration"
  type = object({
    property1 = string
    property2 = number
    # ... other properties
  })
}
```

Usage:

```hcl
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

## Root-Level Configuration

The root `main.tf` includes dummy module calls with `count = 0` that enable validation of all module code:

```hcl
module "networking_validation" {
  source = "./modules/networking"
  count  = 0  # Never creates resources
  
  config = { /* validation config */ }
}
```

This allows `terraform validate` to check all modules without actually creating resources.

## Environments Directory

The `environments/` directory contains environment-specific configurations that compose the modules together.

```
environments/
├── dev/                # Development environment
│   ├── main.tf        # Module composition and configuration
│   ├── variables.tf   # Environment variable definitions
│   ├── terraform.tfvars  # Environment-specific values
│   ├── backend.tf     # Terraform backend configuration
│   └── outputs.tf     # Environment outputs
└── prod/              # Production environment
    ├── main.tf
    ├── variables.tf
    ├── terraform.tfvars
    ├── backend.tf
    └── outputs.tf
```

### Environment Isolation

- Each environment has its own Terraform state file
- State files are stored in separate S3 keys (dev/terraform.tfstate, prod/terraform.tfstate)
- Environments can be deployed and destroyed independently
- Different configurations for dev (cost-optimized) and prod (performance-optimized)

## GitHub Actions Directory

The `.github/workflows/` directory contains CI/CD pipeline definitions.

```
.github/
└── workflows/
    └── terraform-plan.yml  # Terraform validation on pull requests
```

### CI/CD Pipeline Features

- Triggers on pull requests to main branch
- Validates Terraform formatting and syntax
- Generates execution plan
- Posts plan results as PR comment
- Blocks merge if validation fails

## Kiro IDE Integration Directory

The `.kiro/` directory contains Kiro IDE integration files for accelerated development.

```
.kiro/
├── specs/              # Requirements and design documents
│   └── aws-terraform-infrastructure/
│       ├── requirements.md
│       ├── design.md
│       └── tasks.md
├── hooks/              # Agent hooks for automatic validation
│   └── terraform-validate.json
├── steering/           # Coding standards and security rules
│   └── terraform-standards.md
└── settings/
    └── mcp.json       # MCP server configuration (optional)
```

### Kiro Integration Features

- **Specs**: Define requirements and design for AI-assisted code generation
- **Hooks**: Automatic validation on file save (terraform fmt, terraform validate)
- **Steering**: Enforced coding standards and security requirements
- **MCP Servers**: Terraform and GitHub tool integration (optional)

## Scripts Directory

The `scripts/` directory contains utility scripts for infrastructure management.

```
scripts/
└── bootstrap-backend.sh  # Creates S3 bucket and DynamoDB table for state management
```

### Script Usage

```bash
# Bootstrap Terraform backend
./scripts/bootstrap-backend.sh

# The script will:
# - Create S3 bucket for state storage
# - Enable versioning and encryption
# - Create DynamoDB table for state locking
# - Output backend configuration details
```

## Documentation Directory

The `docs/` directory contains project documentation.

```
docs/
├── PROJECT_STRUCTURE.md    # This file
├── BACKEND_SETUP.md        # Detailed backend setup guide
└── architecture.png        # Architecture diagram (to be generated)
```

## File Naming Conventions

### Terraform Files

- `main.tf`: Primary resource definitions
- `variables.tf`: Input variable declarations (single config object)
- `outputs.tf`: Output value declarations
- `backend.tf`: Backend configuration (environment-specific)
- `terraform.tfvars`: Variable values (environment-specific, not committed to git)

### Module Structure

Each module follows a consistent structure:

1. **variables.tf**: Declares single `config` object variable with all properties
2. **main.tf**: Defines all resources and data sources
3. **outputs.tf**: Exports resource identifiers and attributes

### Environment Structure

Each environment follows a consistent structure:

1. **backend.tf**: Configures remote state backend
2. **variables.tf**: Declares environment-level variables
3. **main.tf**: Composes modules and wires them together
4. **terraform.tfvars**: Provides environment-specific values
5. **outputs.tf**: Exports environment-level outputs

## State Management

### State Storage

- **Location**: S3 bucket (terraform-state-{account-id})
- **Encryption**: AES256 server-side encryption
- **Versioning**: Enabled for state history and recovery
- **Access**: Private, no public access

### State Locking

- **Mechanism**: DynamoDB table (terraform-state-lock)
- **Purpose**: Prevents concurrent modifications
- **Billing**: Pay-per-request (cost-effective)

### State Organization

```
S3 Bucket: terraform-state-{account-id}
├── dev/
│   └── terraform.tfstate      # Dev environment state
└── prod/
    └── terraform.tfstate      # Prod environment state
```

## Security Considerations

### Sensitive Files

The following files contain sensitive data and are excluded from git:

- `*.tfvars`: Contains environment-specific values (may include sensitive data)
- `*.tfstate`: Contains resource details including sensitive attributes
- `.terraform/`: Contains provider plugins and cached data

### Secrets Management

- Database passwords: Stored in AWS Parameter Store
- API keys: Stored in AWS Parameter Store
- AWS credentials: Configured via AWS CLI or environment variables
- Never hardcode secrets in Terraform files

## Development Workflow

### Initial Setup

1. Clone repository
2. Run `./scripts/bootstrap-backend.sh` to create backend resources
3. Update `backend.tf` files with your AWS account ID
4. Initialize Terraform: `terraform init`

### Making Changes

1. Create feature branch
2. Modify Terraform files
3. Run `terraform fmt -recursive` to format code
4. Run `terraform validate` to check syntax (validates all modules)
5. Commit and push changes
6. Create pull request
7. CI/CD pipeline validates changes
8. Review plan output in PR comment
9. Merge after approval

### Validation Workflow

```bash
# One-time: Initialize to install modules
terraform init

# Format all files
terraform fmt -recursive

# Validate all modules (checks networking, compute, database, storage)
terraform validate

# Check formatting
terraform fmt -check -recursive
```

The root configuration includes dummy module calls that enable validation of all module code without creating resources.

### Deploying Changes

1. Merge pull request to main branch
2. Navigate to environment directory
3. Run `terraform apply` to deploy changes
4. Review and confirm execution plan
5. Monitor deployment progress

## Best Practices

### Module Development

- Keep modules focused on a single responsibility
- Use object-based variables with single `config` object
- Document all object properties
- Export useful outputs for module consumers
- Test modules independently before integration

### Environment Configuration

- Use separate state files for each environment
- Never share state between environments
- Use environment-specific variable values
- Tag all resources with environment identifier
- Use cost-optimized configurations for dev

### State Management

- Always use remote state backend
- Enable state locking to prevent conflicts
- Never commit state files to git
- Regularly backup state files
- Use state versioning for recovery

### Security

- Enable encryption for all data at rest
- Place databases in private subnets
- Use least-privilege security group rules
- Store secrets in Parameter Store
- Block public access to S3 buckets
- Never use wildcard IAM permissions

## Troubleshooting

### Common Issues

**Issue**: `terraform init` fails with backend error
- **Solution**: Verify S3 bucket and DynamoDB table exist, check AWS credentials

**Issue**: State lock error
- **Solution**: Wait for other operations to complete, or use `terraform force-unlock` if stuck

**Issue**: Resource creation fails
- **Solution**: Check AWS service quotas, verify IAM permissions, review error messages

**Issue**: Module not found error
- **Solution**: Run `terraform init` to install modules

**Issue**: Validation fails
- **Solution**: Run `terraform init` first to install modules, then validate

## Additional Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)
