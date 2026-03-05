# Complete Deployment Guide

This guide walks you through deploying the AWS Terraform infrastructure from scratch, including backend setup, GitHub integration, Docker image deployment, and end-to-end testing.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Step 1: Setup Terraform Remote State Backend](#step-1-setup-terraform-remote-state-backend)
3. [Step 2: Connect to GitHub and Setup CI/CD](#step-2-connect-to-github-and-setup-cicd)
4. [Step 3: Build and Push Docker Image to AWS ECR](#step-3-build-and-push-docker-image-to-aws-ecr)
5. [Step 4: Deploy Infrastructure with Terraform](#step-4-deploy-infrastructure-with-terraform)
6. [Step 5: Test Everything End-to-End](#step-5-test-everything-end-to-end)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, ensure you have:

### Required Tools

- **AWS CLI** (v2.x or later)
  ```bash
  aws --version
  ```
  Install: https://aws.amazon.com/cli/

- **Terraform** (v1.5.0 or later)
  ```bash
  terraform version
  ```
  Install: https://www.terraform.io/downloads

- **Docker** (for building container images)
  ```bash
  docker --version
  ```
  Install: https://www.docker.com/get-started

- **Git** (for version control)
  ```bash
  git --version
  ```

### AWS Account Setup

1. **AWS Account** with administrator access or permissions to create:
   - VPC, Subnets, Internet Gateway, NAT Gateway
   - ECS Cluster, Services, Tasks
   - RDS PostgreSQL instances
   - S3 buckets
   - IAM roles and policies
   - Application Load Balancer
   - ECR repositories

2. **AWS CLI Configured** with credentials:
   ```bash
   aws configure
   ```
   
   You'll need:
   - AWS Access Key ID
   - AWS Secret Access Key
   - Default region (e.g., `us-east-1`)
   - Default output format (e.g., `json`)

3. **Verify AWS credentials**:
   ```bash
   aws sts get-caller-identity
   ```
   
   This should return your AWS Account ID, User ID, and ARN.

---

## Step 1: Setup Terraform Remote State Backend

Terraform needs a remote backend to store state files securely and enable team collaboration.

### Option A: Automated Setup (Recommended)

Use the provided bootstrap script:

```bash
# Make the script executable
chmod +x scripts/bootstrap-backend.sh

# Run the bootstrap script
./scripts/bootstrap-backend.sh
```

The script will:
- Create S3 bucket: `terraform-state-{YOUR_ACCOUNT_ID}`
- Enable versioning and encryption
- Block public access
- Create DynamoDB table: `terraform-state-lock`
- Display your backend configuration

**Expected Output:**
```
=== Backend Setup Complete ===

Backend Configuration:
  S3 Bucket:       terraform-state-123456789012
  DynamoDB Table:  terraform-state-lock
  Region:          us-east-1
```

### Option B: Manual Setup

If you prefer manual setup:

1. **Get your AWS Account ID:**
   ```bash
   export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
   echo $AWS_ACCOUNT_ID
   ```

2. **Create S3 bucket:**
   ```bash
   aws s3api create-bucket \
     --bucket terraform-state-${AWS_ACCOUNT_ID} \
     --region us-east-1
   ```

3. **Enable versioning:**
   ```bash
   aws s3api put-bucket-versioning \
     --bucket terraform-state-${AWS_ACCOUNT_ID} \
     --versioning-configuration Status=Enabled
   ```

4. **Enable encryption:**
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

5. **Block public access:**
   ```bash
   aws s3api put-public-access-block \
     --bucket terraform-state-${AWS_ACCOUNT_ID} \
     --public-access-block-configuration \
       BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
   ```

6. **Create DynamoDB table:**
   ```bash
   aws dynamodb create-table \
     --table-name terraform-state-lock \
     --attribute-definitions AttributeName=LockID,AttributeType=S \
     --key-schema AttributeName=LockID,KeyType=HASH \
     --billing-mode PAY_PER_REQUEST \
     --region us-east-1
   ```

### Update Backend Configuration

Update the backend configuration files with your AWS Account ID:

**For Dev Environment:**
```bash
# Edit environments/dev/backend.tf
# Replace YOUR_ACCOUNT_ID with your actual account ID
sed -i.bak "s/YOUR_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" environments/dev/backend.tf
```

**For Prod Environment:**
```bash
# Edit environments/prod/backend.tf
sed -i.bak "s/YOUR_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" environments/prod/backend.tf
```

**Verify the changes:**
```bash
cat environments/dev/backend.tf
```

Should show:
```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-123456789012"  # Your actual account ID
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
```

---

## Step 2: Connect to GitHub and Setup CI/CD

### 2.1 Initialize Git Repository

If not already initialized:

```bash
# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: AWS Terraform infrastructure"
```

### 2.2 Create GitHub Repository

**Option A: Using GitHub CLI (gh)**

```bash
# Install GitHub CLI if not already installed
# macOS: brew install gh
# Login to GitHub
gh auth login

# Create repository
gh repo create aws-terraform-infrastructure --public --source=. --remote=origin

# Push code
git push -u origin main
```

**Option B: Using GitHub Web Interface**

1. Go to https://github.com/new
2. Repository name: `aws-terraform-infrastructure`
3. Choose Public or Private
4. Do NOT initialize with README (we already have one)
5. Click "Create repository"

6. Add remote and push:
   ```bash
   git remote add origin https://github.com/YOUR_USERNAME/aws-terraform-infrastructure.git
   git branch -M main
   git push -u origin main
   ```

### 2.3 Configure GitHub Secrets for CI/CD

The GitHub Actions workflow needs AWS credentials to run Terraform commands.

**Add secrets to your repository:**

1. Go to your GitHub repository
2. Click **Settings** → **Secrets and variables** → **Actions**
3. Click **New repository secret**

Add these secrets:

| Secret Name | Value | Description |
|-------------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Your AWS access key | IAM user access key |
| `AWS_SECRET_ACCESS_KEY` | Your AWS secret key | IAM user secret key |

**Creating IAM User for GitHub Actions (if needed):**

```bash
# Create IAM user for GitHub Actions
aws iam create-user --user-name github-actions-terraform

# Attach AdministratorAccess policy (or create custom policy with required permissions)
aws iam attach-user-policy \
  --user-name github-actions-terraform \
  --policy-arn arn:aws:iam::aws:policy/AdministratorAccess

# Create access key
aws iam create-access-key --user-name github-actions-terraform
```

Save the `AccessKeyId` and `SecretAccessKey` from the output and add them to GitHub Secrets.

### 2.4 Test GitHub Actions Workflow

The workflow (`.github/workflows/terraform-plan.yml`) triggers on pull requests to `main` branch.

**Test the workflow:**

1. Create a new branch:
   ```bash
   git checkout -b test-ci
   ```

2. Make a small change (e.g., add a comment to a .tf file):
   ```bash
   echo "# Test CI" >> environments/dev/main.tf
   git add environments/dev/main.tf
   git commit -m "Test: Trigger CI workflow"
   git push origin test-ci
   ```

3. Create a Pull Request on GitHub:
   - Go to your repository on GitHub
   - Click "Pull requests" → "New pull request"
   - Select `test-ci` branch
   - Click "Create pull request"

4. Check the workflow:
   - Go to "Actions" tab
   - You should see "Terraform Plan" workflow running
   - It will run: format check, init, validate, and plan
   - Plan results will be posted as a comment on the PR

---

## Step 3: Build and Push Docker Image to AWS ECR

### 3.1 Create ECR Repository

```bash
# Create ECR repository for your application
aws ecr create-repository \
  --repository-name cmc-ts-app \
  --region us-east-1 \
  --image-scanning-configuration scanOnPush=true

# Get the repository URI (save this for later)
export ECR_REPO_URI=$(aws ecr describe-repositories \
  --repository-names cmc-ts-app \
  --region us-east-1 \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository URI: $ECR_REPO_URI"
```

**Expected output:**
```
ECR Repository URI: 123456789012.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app
```

### 3.2 Build Docker Image

```bash
# Navigate to the example app directory
cd example-app

# Build the Docker image
docker build -t cmc-ts-app:latest .

# Tag the image for ECR
docker tag cmc-ts-app:latest ${ECR_REPO_URI}:latest
docker tag cmc-ts-app:latest ${ECR_REPO_URI}:v1.0.0

# Verify images
docker images | grep cmc-ts-app
```

### 3.3 Push Image to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${ECR_REPO_URI}

# Push the image
docker push ${ECR_REPO_URI}:latest
docker push ${ECR_REPO_URI}:v1.0.0

# Verify the image was pushed
aws ecr list-images --repository-name cmc-ts-app --region us-east-1
```

**Expected output:**
```json
{
    "imageIds": [
        {
            "imageDigest": "sha256:...",
            "imageTag": "latest"
        },
        {
            "imageDigest": "sha256:...",
            "imageTag": "v1.0.0"
        }
    ]
}
```

### 3.4 Update Terraform Configuration

Update the container image in your Terraform configuration:

```bash
# Go back to project root
cd ..

# Update dev environment
# Edit environments/dev/terraform.tfvars
# Change container_image line to:
# container_image = "123456789012.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app:latest"
```

Or use sed:
```bash
sed -i.bak "s|container_image = \"nginx:latest\"|container_image = \"${ECR_REPO_URI}:latest\"|g" environments/dev/terraform.tfvars
```

**Verify the change:**
```bash
grep container_image environments/dev/terraform.tfvars
```

---

## Step 4: Deploy Infrastructure with Terraform

### 4.1 Create Parameter Store Secrets

Before deploying, create secrets in AWS Parameter Store:

```bash
# Database password
aws ssm put-parameter \
  --name "/dev/app/db_password" \
  --value "MySecurePassword123!" \
  --type SecureString \
  --region us-east-1 \
  --description "Dev database password"

# Optional: Add other secrets
aws ssm put-parameter \
  --name "/dev/app/api_key" \
  --value "your-api-key-here" \
  --type SecureString \
  --region us-east-1 \
  --description "Dev API key"

# Verify secrets were created
aws ssm get-parameters \
  --names "/dev/app/db_password" "/dev/app/api_key" \
  --with-decryption \
  --region us-east-1
```

### 4.2 Initialize Terraform (Root Level)

```bash
# Initialize at root level (for validation/formatting)
terraform init
```

### 4.3 Deploy Dev Environment

```bash
# Navigate to dev environment
cd environments/dev

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Review the execution plan
terraform plan

# Review the plan output carefully
# It will show all resources that will be created (~34 resources)
```

**Expected resources to be created:**
- VPC, Subnets, Internet Gateway, NAT Gateway, Route Tables
- ECS Cluster, Task Definition, Service
- Application Load Balancer, Target Group, Listener
- RDS PostgreSQL instance
- S3 bucket
- Security Groups
- IAM Roles and Policies
- Auto Scaling configuration

**Apply the configuration:**

```bash
# Apply (this will take 10-15 minutes)
terraform apply

# Type 'yes' when prompted
```

**Wait for completion.** Terraform will create all resources and display outputs.

### 4.4 Save Important Outputs

After successful deployment, save these outputs:

```bash
# Get ALB DNS name
terraform output alb_dns_name

# Get RDS endpoint
terraform output rds_endpoint

# Get S3 bucket name
terraform output s3_bucket_name

# Save all outputs to a file
terraform output > ../../deployment-outputs.txt
```

---

## Step 5: Test Everything End-to-End

### 5.1 Test Terraform Code

```bash
# From environments/dev directory

# Validate Terraform configuration
terraform validate
# Expected: Success! The configuration is valid.

# Check formatting
terraform fmt -check -recursive
# Expected: No output (all files properly formatted)

# Run plan to ensure no drift
terraform plan
# Expected: No changes. Infrastructure is up-to-date.
```

### 5.2 Test AWS Infrastructure

#### Test VPC and Networking

```bash
# Get VPC ID
VPC_ID=$(terraform output -raw vpc_id)

# Verify VPC exists
aws ec2 describe-vpcs --vpc-ids $VPC_ID --region us-east-1

# Check subnets
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --region us-east-1 \
  --query 'Subnets[*].[SubnetId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
  --output table

# Expected: 4 subnets (2 public, 2 private) across 2 AZs
```

#### Test ECS Cluster and Service

```bash
# Check ECS cluster
aws ecs describe-clusters --clusters dev-cluster --region us-east-1

# Check ECS service
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-service \
  --region us-east-1 \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table

# Expected: runningCount should equal desiredCount (2)

# Check ECS tasks
aws ecs list-tasks --cluster dev-cluster --service-name dev-service --region us-east-1

# Get task details
TASK_ARN=$(aws ecs list-tasks --cluster dev-cluster --service-name dev-service --region us-east-1 --query 'taskArns[0]' --output text)
aws ecs describe-tasks --cluster dev-cluster --tasks $TASK_ARN --region us-east-1
```

#### Test RDS Database

```bash
# Get RDS endpoint
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)

# Check RDS instance status
aws rds describe-db-instances \
  --db-instance-identifier dev-db \
  --region us-east-1 \
  --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Endpoint.Address,Endpoint.Port]' \
  --output table

# Expected: DBInstanceStatus should be "available"
```

#### Test S3 Bucket

```bash
# Get S3 bucket name
S3_BUCKET=$(terraform output -raw s3_bucket_name)

# Check bucket exists
aws s3 ls s3://$S3_BUCKET

# Check bucket versioning
aws s3api get-bucket-versioning --bucket $S3_BUCKET

# Check bucket encryption
aws s3api get-bucket-encryption --bucket $S3_BUCKET

# Check public access block
aws s3api get-public-access-block --bucket $S3_BUCKET
```

### 5.3 Test Application

#### Test ALB Health

```bash
# Get ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test ALB endpoint (may take a few minutes for tasks to be healthy)
curl http://$ALB_DNS

# Expected output: "Welcome to CMC TS"

# Test health endpoint
curl http://$ALB_DNS/health

# Expected output: {"status":"healthy"}
```

#### Test from Browser

```bash
# Print the ALB URL
echo "Application URL: http://$ALB_DNS"
```

Open this URL in your browser. You should see:
- **Homepage**: "Welcome to CMC TS"
- **Health endpoint** (`/health`): `{"status":"healthy"}`

#### Check ALB Target Health

```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names dev-tg \
  --region us-east-1 \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason]' \
  --output table

# Expected: All targets should be "healthy"
```

### 5.4 Test GitHub Actions CI

#### Test via Pull Request

1. **Make a change:**
   ```bash
   git checkout -b test-infrastructure
   
   # Make a small change
   echo "# Infrastructure test" >> environments/dev/main.tf
   
   git add .
   git commit -m "Test: Infrastructure validation"
   git push origin test-infrastructure
   ```

2. **Create Pull Request:**
   - Go to GitHub repository
   - Create PR from `test-infrastructure` to `main`

3. **Verify workflow runs:**
   - Go to "Actions" tab
   - Check "Terraform Plan" workflow
   - Verify all steps pass:
     - ✅ Terraform Format Check
     - ✅ Terraform Init
     - ✅ Terraform Validate
     - ✅ Terraform Plan
   - Check PR comment with plan output

4. **Merge PR** (if all checks pass)

### 5.5 Test Auto-Scaling

#### Simulate High CPU Load

```bash
# Get ECS service details
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-service \
  --region us-east-1 \
  --query 'services[0].[desiredCount,runningCount]'

# Current count should be 2

# To test auto-scaling, you would need to generate load on the application
# This would require a load testing tool like Apache Bench or hey

# Example (if you have 'hey' installed):
# hey -z 5m -c 50 http://$ALB_DNS

# Monitor scaling activity
aws application-autoscaling describe-scaling-activities \
  --service-namespace ecs \
  --resource-id service/dev-cluster/dev-service \
  --region us-east-1
```

### 5.6 Test Security

#### Verify Encryption

```bash
# Check RDS encryption
aws rds describe-db-instances \
  --db-instance-identifier dev-db \
  --region us-east-1 \
  --query 'DBInstances[0].StorageEncrypted'

# Expected: true

# Check S3 encryption
aws s3api get-bucket-encryption --bucket $S3_BUCKET

# Expected: AES256 encryption enabled
```

#### Verify Private Subnet Placement

```bash
# Check RDS subnet group
aws rds describe-db-subnet-groups \
  --db-subnet-group-name dev-db-subnet-group \
  --region us-east-1 \
  --query 'DBSubnetGroups[0].Subnets[*].[SubnetIdentifier,SubnetAvailabilityZone.Name]' \
  --output table

# Verify these are private subnets (should match private subnet IDs from Terraform output)
```

#### Verify Security Groups

```bash
# Get ECS task security group
ECS_SG=$(terraform output -raw ecs_task_security_group_id)

# Check security group rules
aws ec2 describe-security-groups --group-ids $ECS_SG --region us-east-1

# Verify:
# - Ingress only from ALB security group
# - Egress allows outbound traffic
```

---

## Troubleshooting

### Issue: Terraform Backend Initialization Fails

**Error:**
```
Error: Failed to get existing workspaces: S3 bucket does not exist
```

**Solution:**
1. Verify S3 bucket exists:
   ```bash
   aws s3 ls | grep terraform-state
   ```

2. Check bucket name in `backend.tf` matches actual bucket name

3. Verify AWS credentials have S3 access:
   ```bash
   aws s3 ls s3://terraform-state-${AWS_ACCOUNT_ID}
   ```

### Issue: ECS Tasks Not Starting

**Error:** Tasks fail to start or immediately stop

**Solution:**
1. Check ECS task logs:
   ```bash
   aws logs tail /ecs/dev-task --follow --region us-east-1
   ```

2. Verify ECR image exists and is accessible:
   ```bash
   aws ecr describe-images --repository-name cmc-ts-app --region us-east-1
   ```

3. Check IAM task execution role has ECR permissions

4. Verify Parameter Store secrets exist:
   ```bash
   aws ssm get-parameter --name "/dev/app/db_password" --region us-east-1
   ```

### Issue: ALB Returns 503 Service Unavailable

**Error:** ALB endpoint returns 503 error

**Solution:**
1. Check target health:
   ```bash
   aws elbv2 describe-target-health --target-group-arn $TG_ARN --region us-east-1
   ```

2. If targets are unhealthy, check:
   - ECS tasks are running
   - Health check endpoint (`/health`) returns 200
   - Security groups allow ALB → ECS traffic

3. Check ECS service events:
   ```bash
   aws ecs describe-services --cluster dev-cluster --services dev-service --region us-east-1 --query 'services[0].events[0:5]'
   ```

### Issue: GitHub Actions Workflow Fails

**Error:** Workflow fails with authentication error

**Solution:**
1. Verify GitHub Secrets are set correctly:
   - Go to Settings → Secrets and variables → Actions
   - Check `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` exist

2. Test AWS credentials locally:
   ```bash
   export AWS_ACCESS_KEY_ID="your-key"
   export AWS_SECRET_ACCESS_KEY="your-secret"
   aws sts get-caller-identity
   ```

3. Verify IAM user has required permissions

### Issue: RDS Connection Timeout

**Error:** Cannot connect to RDS from ECS tasks

**Solution:**
1. Verify RDS is in private subnets
2. Check security group allows traffic from ECS security group:
   ```bash
   aws ec2 describe-security-groups --group-ids $RDS_SG --region us-east-1
   ```

3. Verify ECS tasks are in same VPC as RDS

4. Check RDS endpoint is correct in application configuration

### Issue: High AWS Costs

**Solution:**
1. Stop RDS instance when not in use:
   ```bash
   aws rds stop-db-instance --db-instance-identifier dev-db --region us-east-1
   ```

2. Scale down ECS service:
   ```bash
   aws ecs update-service --cluster dev-cluster --service dev-service --desired-count 0 --region us-east-1
   ```

3. Delete NAT Gateway (will break outbound internet from private subnets):
   ```bash
   # Not recommended unless you're sure
   # NAT Gateway costs ~$32/month
   ```

4. Use smaller RDS instance type in dev:
   - Edit `environments/dev/terraform.tfvars`
   - Change `db_instance_class = "db.t3.micro"` (already set)

---

## Next Steps

After successful deployment:

1. **Set up monitoring:**
   - Enable CloudWatch alarms for ECS, RDS, ALB
   - Set up CloudWatch dashboards

2. **Configure custom domain:**
   - Register domain in Route 53
   - Create SSL certificate in ACM
   - Update ALB listener to use HTTPS

3. **Deploy to production:**
   ```bash
   cd environments/prod
   terraform init
   terraform plan
   terraform apply
   ```

4. **Set up CI/CD for deployments:**
   - Add `terraform apply` workflow for main branch
   - Implement blue/green deployments for ECS

5. **Implement backup strategy:**
   - Enable automated RDS snapshots
   - Configure S3 bucket replication

---

## Summary

You've successfully:

✅ Created Terraform remote state backend (S3 + DynamoDB)  
✅ Connected code to GitHub with CI/CD pipeline  
✅ Built and pushed Docker image to AWS ECR  
✅ Deployed complete AWS infrastructure with Terraform  
✅ Tested infrastructure, application, and CI/CD pipeline  

Your infrastructure is now running and ready for development!

**Important URLs:**
- Application: `http://<ALB_DNS>`
- GitHub Repository: `https://github.com/<USERNAME>/aws-terraform-infrastructure`
- AWS Console: `https://console.aws.amazon.com/`

**Cost Estimate (Dev Environment):**
- ECS Fargate: ~$15-20/month
- RDS t3.micro: ~$15/month
- NAT Gateway: ~$32/month
- ALB: ~$16/month
- **Total: ~$78-83/month**

Remember to stop/destroy resources when not in use to minimize costs!
