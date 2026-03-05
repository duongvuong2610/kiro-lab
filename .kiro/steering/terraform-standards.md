# Terraform Coding Standards

## Module Variable Structure

All modules MUST use object-based variable configuration:

```hcl
variable "config" {
  description = "Module configuration"
  type = object({
    # Define all module inputs as object properties
    property_name = type
  })
}
```

### Benefits
- Cleaner module interfaces
- Single configuration object per module
- Easier to pass configuration between modules
- Better IDE autocomplete support

### Example Usage

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

## Naming Conventions

- Resources: `{resource_type}_{environment}_{purpose}`
- Variables: Use `config` as the single object variable name
- Outputs: snake_case
- Modules: kebab-case directories

## Tagging Strategy

All resources MUST include:
- Environment: dev/prod
- ManagedBy: terraform
- Name: descriptive resource name

## Security Requirements

- MUST enable encryption for all data storage (RDS, S3)
- MUST place databases in private subnets
- MUST NOT use wildcard (*) in IAM policies
- MUST retrieve secrets from Parameter Store
- MUST block public access to S3 buckets
- MUST use least-privilege security group rules

## Validation and Formatting

Run from project root (no need to init each module):

```bash
# Format all files
terraform fmt -recursive

# Validate all modules
terraform validate

# Check formatting
terraform fmt -check -recursive
```

## Best Practices

- Use object variables for all module inputs
- Document all object properties with descriptions
- Export useful outputs for module consumers
- Use data sources for dynamic lookups
- Enable versioning for state backends
- Always run fmt before committing
