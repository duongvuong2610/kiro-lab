# Step 4: Deploy Infrastructure with Terraform

## Prerequisites

- ✅ Step 1 Complete: Terraform backend created
- ✅ Step 2 Complete: GitHub CI/CD working
- ✅ Step 3 Complete: Docker image pushed to ECR

## Commands to Run

### 1. Create Required Parameter Store Secrets

```bash
# Create database password secret
aws ssm put-parameter \
  --name "/dev/app/db_password" \
  --value "MySecurePassword123!" \
  --type SecureString \
  --region us-east-1 \
  --profile kiro-lab

# Create API key secret
aws ssm put-parameter \
  --name "/dev/app/api_key" \
  --value "dev-api-key-12345" \
  --type SecureString \
  --region us-east-1 \
  --profile kiro-lab
```

### 2. Navigate to Dev Environment

```bash
cd environments/dev
```

### 3. Initialize Terraform (if not already done)

```bash
terraform init
```

### 4. Review the Deployment Plan

```bash
terraform plan
```

**Expected:** You should see approximately 34 resources to be created:
- VPC, Subnets, Internet Gateway, NAT Gateways
- Security Groups
- Application Load Balancer
- ECS Cluster, Service, Task Definition
- RDS PostgreSQL Database
- S3 Bucket
- IAM Roles and Policies
- CloudWatch Log Groups
- Auto Scaling Configuration

### 5. Apply the Configuration

```bash
terraform apply
```

Type `yes` when prompted.

**Duration:** 10-15 minutes (RDS and NAT Gateways take the longest)

### 6. Save Outputs

```bash
terraform output > ../../deployment-outputs.txt
cd ../..
cat deployment-outputs.txt
```

## Important Outputs

After deployment, you'll get:
- `alb_dns_name` - Load balancer URL to access your application
- `ecr_repository_url` - ECR repository URL
- `ecs_cluster_name` - ECS cluster name
- `rds_endpoint` - Database endpoint
- `s3_bucket_name` - S3 bucket name
- `vpc_id` - VPC ID

## Test the Deployment

```bash
# Get ALB DNS name
ALB_DNS=$(cd environments/dev && terraform output -raw alb_dns_name)
echo "Application URL: http://$ALB_DNS"

# Wait 2-3 minutes for ECS tasks to become healthy
echo "Waiting for ECS tasks to be healthy..."
sleep 180

# Test root endpoint
curl http://$ALB_DNS
# Expected: "Welcome to CMC TS"

# Test health endpoint
curl http://$ALB_DNS/health
# Expected: {"status":"healthy"}
```

## Verify Resources in AWS Console

1. **ECS Service:**
   - Go to: https://console.aws.amazon.com/ecs
   - Cluster: `dev-cluster`
   - Service: `dev-service`
   - Check that tasks are running

2. **Load Balancer:**
   - Go to: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LoadBalancers
   - Find: `dev-alb`
   - Check target group health

3. **RDS Database:**
   - Go to: https://console.aws.amazon.com/rds
   - Instance: `dev-db`
   - Status should be "Available"

## Troubleshooting

### If ECS tasks fail to start:

```bash
# Check ECS service events
aws ecs describe-services \
  --cluster dev-cluster \
  --services dev-service \
  --region us-east-1 \
  --profile kiro-lab

# Check task logs
aws logs tail /ecs/dev/dev-service \
  --follow \
  --region us-east-1 \
  --profile kiro-lab
```

### If ALB health checks fail:

```bash
# Check target group health
aws elbv2 describe-target-health \
  --target-group-arn $(cd environments/dev && terraform output -raw alb_target_group_arn) \
  --region us-east-1 \
  --profile kiro-lab
```

### If Terraform apply fails:

1. Check the error message carefully
2. Verify Parameter Store secrets exist
3. Ensure ECR image is pushed
4. Check AWS service quotas
5. Run `terraform plan` again to see what's failing

## Cleanup (When Done Testing)

```bash
# Destroy all infrastructure
cd environments/dev
terraform destroy

# Type 'yes' when prompted
# Duration: 5-10 minutes
```

**Note:** This will delete all resources except:
- S3 backend bucket (terraform-state-471112857175)
- DynamoDB lock table (terraform-state-lock)
- ECR repository (cmc-ts-app)
- Parameter Store secrets

To delete ECR:
```bash
aws ecr delete-repository \
  --repository-name cmc-ts-app \
  --force \
  --region us-east-1 \
  --profile kiro-lab
```

---

## Summary

After completing Step 4, you will have:
- ✅ Full 3-tier AWS infrastructure deployed
- ✅ Containerized application running on ECS Fargate
- ✅ Load-balanced and auto-scaled
- ✅ PostgreSQL database in private subnet
- ✅ S3 storage with lifecycle policies
- ✅ All resources tagged and managed by Terraform

**Total Resources Created:** ~34  
**Estimated Monthly Cost (Dev):** $50-80 USD  
**Deployment Time:** 10-15 minutes
