# Terraform Backend Setup Guide

This guide provides detailed instructions for setting up the Terraform backend infrastructure required for state management.

## Overview

Terraform uses a backend to store state files and coordinate operations between team members. This project uses:

- **S3 Bucket**: Stores Terraform state files with versioning and encryption
- **DynamoDB Table**: Provides state locking to prevent concurrent modifications

## Prerequisites

- AWS CLI installed and configured
- AWS account with permissions to create S3 buckets and DynamoDB tables
- Bash shell (for running the bootstrap script)

## Quick Setup (Automated)

The easiest way to set up the backend is using the provided bootstrap script:

```bash
# Run the bootstrap script
./scripts/bootstrap-backend.sh

# The script will:
# 1. Retrieve your AWS account ID
# 2. Create S3 bucket: terraform-state-{account-id}
# 3. Enable versioning, encryption, and block public access
# 4. Create DynamoDB table: terraform-state-lock
# 5. Display backend configuration details
```

After running the script, update the `backend.tf` files in `environments/dev/` and `environments/prod/` with your AWS account ID.

## Manual Setup (Step-by-Step)

If you prefer to set up the backend manually or need to customize the configuration:

### Step 1: Get Your AWS Account ID

```bash
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "AWS Account ID: $AWS_ACCOUNT_ID"
```

### Step 2: Create S3 Bucket

```bash
# Create the bucket
aws s3api create-bucket \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --region us-east-1

# For regions other than us-east-1, add location constraint:
# aws s3api create-bucket \
#   --bucket terraform-state-${AWS_ACCOUNT_ID} \
#   --region us-west-2 \
#   --create-bucket-configuration LocationConstraint=us-west-2
```

### Step 3: Enable Versioning

Versioning allows you to recover previous versions of your state file:

```bash
aws s3api put-bucket-versioning \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --versioning-configuration Status=Enabled
```

### Step 4: Enable Encryption

Encrypt state files at rest using AES256:

```bash
aws s3api put-bucket-encryption \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      },
      "BucketKeyEnabled": true
    }]
  }'
```

### Step 5: Block Public Access

Ensure the state bucket is never publicly accessible:

```bash
aws s3api put-public-access-block \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

### Step 6: Add Bucket Policy (Optional but Recommended)

Enforce HTTPS-only access to the bucket:

```bash
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureTransport",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::terraform-state-${AWS_ACCOUNT_ID}",
                "arn:aws:s3:::terraform-state-${AWS_ACCOUNT_ID}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-policy \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --policy file:///tmp/bucket-policy.json

rm /tmp/bucket-policy.json
```

### Step 7: Create DynamoDB Table

Create a table for state locking:

```bash
aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1 \
  --tags Key=ManagedBy,Value=Terraform Key=Purpose,Value=StateLocking
```

### Step 8: Verify Resources

```bash
# Verify S3 bucket
aws s3api head-bucket --bucket terraform-state-${AWS_ACCOUNT_ID}

# Verify DynamoDB table
aws dynamodb describe-table \
  --table-name terraform-state-lock \
  --query 'Table.TableStatus' \
  --output text
```

## Backend Configuration

After creating the backend resources, update the `backend.tf` files:

### Development Environment

Edit `environments/dev/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-123456789012"  # Replace with your account ID
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

### Production Environment

Edit `environments/prod/backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-123456789012"  # Replace with your account ID
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

## Initialize Terraform

After configuring the backend, initialize Terraform in each environment:

```bash
# Initialize dev environment
cd environments/dev
terraform init

# Initialize prod environment
cd ../prod
terraform init
```

You should see output indicating that the backend has been successfully configured:

```
Initializing the backend...

Successfully configured the backend "s3"! Terraform will automatically
use this backend unless the backend configuration changes.
```

## Backend Migration

If you need to migrate from local state to remote backend or change backend configuration:

```bash
# Terraform will detect the change and prompt for migration
terraform init

# Follow the prompts to migrate state
# Terraform will copy local state to the remote backend
```

## State Locking

The DynamoDB table provides state locking to prevent concurrent modifications:

- When you run `terraform apply`, Terraform acquires a lock
- Other users attempting to modify the same state will be blocked
- The lock is automatically released when the operation completes

### Handling Stuck Locks

If a lock becomes stuck (e.g., process crashed):

```bash
# List current locks (requires AWS CLI and jq)
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-1

# Force unlock using Terraform (use with caution)
terraform force-unlock LOCK_ID
```

## Security Best Practices

### IAM Permissions

Users need the following IAM permissions for backend access:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject"
      ],
      "Resource": [
        "arn:aws:s3:::terraform-state-*",
        "arn:aws:s3:::terraform-state-*/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ],
      "Resource": "arn:aws:dynamodb:*:*:table/terraform-state-lock"
    }
  ]
}
```

### State File Security

- State files may contain sensitive data (passwords, keys)
- Never commit state files to version control
- Limit access to the S3 bucket using IAM policies
- Enable CloudTrail logging for audit trail
- Use encryption at rest and in transit

## Backup and Recovery

### State File Backups

S3 versioning provides automatic backups:

```bash
# List all versions of a state file
aws s3api list-object-versions \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --prefix dev/terraform.tfstate

# Restore a previous version
aws s3api get-object \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --key dev/terraform.tfstate \
  --version-id VERSION_ID \
  terraform.tfstate.backup
```

### Manual Backup

Create a manual backup before major changes:

```bash
# Pull current state
terraform state pull > terraform.tfstate.backup

# Store backup securely
aws s3 cp terraform.tfstate.backup \
  s3://terraform-state-${AWS_ACCOUNT_ID}/backups/$(date +%Y%m%d-%H%M%S).tfstate
```

## Cost Considerations

### S3 Costs

- Storage: Minimal (state files are typically < 1 MB)
- Requests: Low (only during Terraform operations)
- Versioning: Keeps all versions (consider lifecycle policies for old versions)

### DynamoDB Costs

- Billing Mode: Pay-per-request (no minimum cost)
- Typical Cost: < $1/month for small teams
- Lock operations are infrequent and short-lived

### Cost Optimization

To reduce costs for old state versions:

```bash
# Add lifecycle policy to delete old versions after 90 days
aws s3api put-bucket-lifecycle-configuration \
  --bucket terraform-state-${AWS_ACCOUNT_ID} \
  --lifecycle-configuration '{
    "Rules": [{
      "Id": "DeleteOldVersions",
      "Status": "Enabled",
      "NoncurrentVersionExpiration": {
        "NoncurrentDays": 90
      }
    }]
  }'
```

## Troubleshooting

### Error: Bucket already exists

If the bucket name is taken:

```bash
# Use a different bucket name with a unique suffix
export BUCKET_NAME="terraform-state-${AWS_ACCOUNT_ID}-$(date +%s)"
```

### Error: Access Denied

Check your AWS credentials and IAM permissions:

```bash
# Verify credentials
aws sts get-caller-identity

# Check S3 access
aws s3 ls s3://terraform-state-${AWS_ACCOUNT_ID}
```

### Error: State lock timeout

If operations timeout waiting for lock:

1. Check if another user is running Terraform
2. Wait for their operation to complete
3. If stuck, use `terraform force-unlock` (with caution)

### Error: Backend initialization failed

Common causes:

- Bucket or table doesn't exist: Run bootstrap script
- Incorrect bucket name in backend.tf: Verify account ID
- Wrong region: Ensure region matches in backend.tf and AWS resources

## Multi-Region Setup

To use a different AWS region:

```bash
# Set region
export AWS_REGION="us-west-2"

# Run bootstrap script with region
AWS_REGION=us-west-2 ./scripts/bootstrap-backend.sh

# Update backend.tf files with the new region
```

## Team Collaboration

### Onboarding New Team Members

1. Ensure they have AWS CLI configured
2. Grant IAM permissions for S3 and DynamoDB access
3. Share the backend configuration (bucket name, region)
4. Have them run `terraform init` in each environment

### Best Practices

- Communicate before running `terraform apply`
- Use workspaces or separate environments for experimentation
- Review plans before applying
- Use CI/CD for production deployments
- Document any manual changes to infrastructure

## Additional Resources

- [Terraform Backend Configuration](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [S3 Backend Documentation](https://www.terraform.io/docs/language/settings/backends/s3.html)
- [State Locking](https://www.terraform.io/docs/language/state/locking.html)
- [AWS S3 Best Practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
