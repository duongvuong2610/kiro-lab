# Complete Deployment Guide

This guide walks you through deploying the AWS Terraform infrastructure from scratch to a running application.

## Quick Reference

**AWS Account:** 471112857175  
**AWS Profile:** kiro-lab  
**Region:** us-east-1  
**Backend Bucket:** terraform-state-471112857175

## Prerequisites

- AWS CLI configured with `kiro-lab` profile
- Terraform >= 1.5.0
- Docker with buildx support
- Git

## Deployment Steps

### Step 1: Verify Backend Setup

The Terraform backend is already configured:

```bash
# Verify backend resources exist
aws s3 ls s3://terraform-state-471112857175 --profile kiro-lab
aws dynamodb describe-table --table-name terraform-state-lock --region us-east-1 --profile kiro-lab
```

### Step 2: Build and Push Docker Image (CRITICAL: Correct Architecture)

The Docker image MUST be built for x86_64/AMD64 architecture (ECS Fargate requirement):

```bash
# Set AWS profile
export AWS_PROFILE=kiro-lab

# Get ECR repository URI
export ECR_REPO_URI=$(aws ecr describe-repositories \
  --repository-names cmc-ts-app \
  --region us-east-1 \
  --profile kiro-lab \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository: $ECR_REPO_URI"

# Navigate to app directory
cd example-app

# Build for x86_64/AMD64 architecture (REQUIRED for ECS Fargate)
docker buildx build --platform linux/amd64 -t cmc-ts-app:latest .

# Tag for ECR
docker tag cmc-ts-app:latest ${ECR_REPO_URI}:latest
docker tag cmc-ts-app:latest ${ECR_REPO_URI}:v1.0.1

# Login to ECR
aws ecr get-login-password --region us-east-1 --profile kiro-lab | \
  docker login --username AWS --password-stdin ${ECR_REPO_URI}

# Push to ECR
docker push ${ECR_REPO_URI}:latest
docker push ${ECR_REPO_URI}:v1.0.1

cd ..
```

**Note:** If `docker buildx` is not available, use:
```bash
docker build --platform linux/amd64 -t cmc-ts-app:latest .
```

### Step 3: Create Parameter Store Secrets

```bash
# Create database password
aws ssm put-parameter \
  --name "/dev/app/db_password" \
  --value "MySecurePassword123!" \
  --type SecureString \
  --region us-east-1 \
  --profile kiro-lab

# Create API key
aws ssm put-parameter \
  --name "/dev/app/api_key" \
  --value "dev-api-key-12345" \
  --type SecureString \
  --region us-east-1 \
  --profile kiro-lab
```

### Step 4: Deploy Infrastructure

```bash
# Navigate to dev environment
cd environments/dev

# Initialize Terraform
terraform init

# Review plan
terraform plan

# Apply (takes 10-15 minutes)
terraform apply

# Save outputs
terraform output > ../../deployment-outputs.txt
cd ../..
```

### Step 5: Force ECS Service Deployment

After infrastructure is deployed, force ECS to deploy with the correct image:

```bash
aws ecs update-service \
  --cluster dev-cluster \
  --service dev-service \
  --force-new-deployment \
  --region us-east-1 \
  --profile kiro-lab
```

### Step 6: Test the Application

Wait 3-5 minutes for tasks to start and become healthy, then test:

```bash
# Get ALB DNS
cd environments/dev
ALB_DNS=$(terraform output -raw alb_dns_name)
echo "Application URL: http://$ALB_DNS"

# Test application
curl http://$ALB_DNS
# Expected: "Welcome to CMC TS"

curl http://$ALB_DNS/health
# Expected: {"status":"healthy"}
```

## Monitoring Deployment

### Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-service \
  --region us-east-1 \
  --profile kiro-lab \
  --query 'services[0].[serviceName,status,runningCount,desiredCount]' \
  --output table
```

### Check Task Status

```bash
# List tasks
aws ecs list-tasks \
  --cluster dev-cluster \
  --service-name dev-service \
  --region us-east-1 \
  --profile kiro-lab

# Get task details
TASK_ARN=$(aws ecs list-tasks \
  --cluster dev-cluster \
  --service-name dev-service \
  --region us-east-1 \
  --profile kiro-lab \
  --query 'taskArns[0]' \
  --output text)

aws ecs describe-tasks \
  --cluster dev-cluster \
  --tasks $TASK_ARN \
  --region us-east-1 \
  --profile kiro-lab
```

### Check Target Health

```bash
# Get target group ARN
TG_ARN=$(aws elbv2 describe-target-groups \
  --names dev-tg \
  --region us-east-1 \
  --profile kiro-lab \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --profile kiro-lab
```

## Troubleshooting

### Issue: ECS Tasks Fail with "exec format error"

**Cause:** Docker image built for wrong architecture (ARM64 instead of AMD64)

**Solution:** Rebuild image with correct architecture (see Step 2 above)

### Issue: Tasks Not Starting

```bash
# Check task logs
aws logs tail /ecs/dev-task --follow --region us-east-1 --profile kiro-lab
```

### Issue: ALB Returns 503

**Cause:** No healthy targets

**Solution:**
1. Check ECS tasks are running
2. Verify health check endpoint returns 200
3. Check security groups allow ALB → ECS traffic

### Issue: Health Checks Failing

```bash
# Check target group health details
aws elbv2 describe-target-health \
  --target-group-arn $TG_ARN \
  --region us-east-1 \
  --profile kiro-lab \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' \
  --output table
```

## GitHub CI/CD Setup

### Add GitHub Secrets

Go to: `https://github.com/duongvuong2610/kiro-lab/settings/secrets/actions`

Add these secrets:
1. **AWS_ACCESS_KEY_ID** - From `~/.aws/credentials` under `[kiro-lab]`
2. **AWS_SECRET_ACCESS_KEY** - From `~/.aws/credentials` under `[kiro-lab]`

### Test CI/CD

```bash
# Create test branch
git checkout -b test-ci
echo "# Test" >> README.md
git add README.md
git commit -m "Test: CI workflow"
git push origin test-ci
```

Create a PR on GitHub and check the Actions tab.

## Cleanup

To destroy all infrastructure:

```bash
cd environments/dev
terraform destroy

# Delete ECR repository
aws ecr delete-repository \
  --repository-name cmc-ts-app \
  --force \
  --region us-east-1 \
  --profile kiro-lab
```

## Cost Estimate (Dev Environment)

- ECS Fargate: ~$15-20/month
- RDS t3.micro: ~$15/month
- NAT Gateway: ~$32/month
- ALB: ~$16/month
- **Total: ~$78-83/month**

## Resources Created

- VPC with public/private subnets across 2 AZs
- Internet Gateway and NAT Gateways
- Application Load Balancer
- ECS Fargate cluster and service
- RDS PostgreSQL database
- S3 bucket with lifecycle policies
- Security groups and IAM roles
- CloudWatch log groups
- Auto-scaling configuration

**Total: ~34 resources**

## Important URLs

- Application: `http://<ALB_DNS>` (from terraform output)
- GitHub Repository: https://github.com/duongvuong2610/kiro-lab
- AWS Console: https://console.aws.amazon.com/

## Next Steps

After successful deployment:

1. Set up custom domain with Route 53
2. Add SSL certificate with ACM
3. Configure CloudWatch alarms
4. Deploy to production environment
5. Implement backup strategy
