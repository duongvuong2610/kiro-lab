# Quick Start Commands

This is a quick reference for the deployment steps. For detailed instructions, see `docs/DEPLOYMENT_GUIDE.md` and `GITHUB_SETUP.md`.

## Current Status

✅ **Step 1 Complete:** Terraform backend created
- S3 Bucket: `terraform-state-471112857175`
- DynamoDB Table: `terraform-state-lock`
- Backend config updated in `environments/dev/backend.tf` and `environments/prod/backend.tf`

## Next: Test Terraform Init (Option 2)

```bash
# Set AWS profile
export AWS_PROFILE=kiro-lab

# Navigate to dev environment
cd environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Check formatting
terraform fmt -check

# Go back to root
cd ../..
```

**Expected:** Terraform should successfully connect to S3 backend and download AWS provider.

## Then: GitHub Setup (Option 1)

### Quick GitHub Setup

```bash
# Initialize git
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: AWS Terraform infrastructure"

# Create GitHub repo (using GitHub CLI)
gh auth login
gh repo create aws-terraform-infrastructure --public --source=. --remote=origin
git push -u origin main
```

### Add GitHub Secrets

Go to: `https://github.com/YOUR_USERNAME/aws-terraform-infrastructure/settings/secrets/actions`

Add these secrets:
1. **AWS_ACCESS_KEY_ID** - Get from `~/.aws/credentials` under `[kiro-lab]`
2. **AWS_SECRET_ACCESS_KEY** - Get from `~/.aws/credentials` under `[kiro-lab]`

### Test CI/CD

```bash
# Create test branch
git checkout -b test-ci
echo "# Test" >> README.md
git add README.md
git commit -m "Test: CI workflow"
git push origin test-ci
```

Then create a PR on GitHub and check the Actions tab.

## After GitHub Setup: Build Docker Image

```bash
# Create ECR repository
aws ecr create-repository --repository-name cmc-ts-app --region us-east-1 --profile kiro-lab

# Get ECR URI
export ECR_REPO_URI=$(aws ecr describe-repositories --repository-names cmc-ts-app --region us-east-1 --profile kiro-lab --query 'repositories[0].repositoryUri' --output text)
echo $ECR_REPO_URI

# Build Docker image
cd example-app
docker build -t cmc-ts-app:latest .

# Tag for ECR
docker tag cmc-ts-app:latest ${ECR_REPO_URI}:latest

# Login to ECR
aws ecr get-login-password --region us-east-1 --profile kiro-lab | docker login --username AWS --password-stdin ${ECR_REPO_URI}

# Push to ECR
docker push ${ECR_REPO_URI}:latest

# Go back to root
cd ..
```

## Update Terraform Config with ECR Image

```bash
# Update container image in terraform.tfvars
# Replace the container_image line with your ECR URI
# Example: container_image = "471112857175.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app:latest"
```

Or use sed:
```bash
sed -i.bak "s|container_image = \"nginx:latest\"|container_image = \"${ECR_REPO_URI}:latest\"|g" environments/dev/terraform.tfvars
```

## Deploy Infrastructure

```bash
# Create Parameter Store secrets
aws ssm put-parameter --name "/dev/app/db_password" --value "MySecurePassword123!" --type SecureString --region us-east-1 --profile kiro-lab

# Navigate to dev environment
cd environments/dev

# Review plan
terraform plan

# Apply (creates ~34 resources, takes 10-15 minutes)
terraform apply

# Save outputs
terraform output > ../../deployment-outputs.txt
```

## Test Deployment

```bash
# Get ALB DNS
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test application (wait a few minutes for tasks to be healthy)
curl http://$ALB_DNS
# Expected: "Welcome to CMC TS"

curl http://$ALB_DNS/health
# Expected: {"status":"healthy"}
```

## Useful Commands

```bash
# Check AWS identity
aws sts get-caller-identity --profile kiro-lab

# List S3 buckets
aws s3 ls --profile kiro-lab

# Check ECS service
aws ecs describe-services --cluster dev-cluster --services dev-service --region us-east-1 --profile kiro-lab

# Check RDS status
aws rds describe-db-instances --db-instance-identifier dev-db --region us-east-1 --profile kiro-lab

# View Terraform state
cd environments/dev
terraform state list
terraform show
```

## Cleanup (When Done)

```bash
# Destroy infrastructure
cd environments/dev
terraform destroy

# Delete ECR images
aws ecr batch-delete-image --repository-name cmc-ts-app --image-ids imageTag=latest --region us-east-1 --profile kiro-lab

# Delete ECR repository
aws ecr delete-repository --repository-name cmc-ts-app --force --region us-east-1 --profile kiro-lab

# Note: Keep S3 backend and DynamoDB table if you plan to use Terraform again
```

## File Reference

- **Deployment Guide:** `docs/DEPLOYMENT_GUIDE.md` - Complete step-by-step guide
- **GitHub Setup:** `GITHUB_SETUP.md` - Detailed GitHub and CI/CD setup
- **Quick Start:** `QUICK_START.md` - This file (quick reference)
- **README:** `README.md` - Project overview and documentation
- **AWS Resources:** `docs/AWS_RESOURCES.md` - List of all AWS resources created

## Support

If you encounter issues:
1. Check the Troubleshooting section in `docs/DEPLOYMENT_GUIDE.md`
2. Verify AWS credentials: `aws sts get-caller-identity --profile kiro-lab`
3. Check Terraform logs: `TF_LOG=DEBUG terraform plan`
4. Review GitHub Actions logs in the Actions tab

---

**AWS Account:** 471112857175  
**AWS Profile:** kiro-lab  
**Region:** us-east-1  
**Backend Bucket:** terraform-state-471112857175
