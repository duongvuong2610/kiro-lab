# AWS Resources Created by Terraform

This document lists all AWS resources that will be created when applying the Terraform configuration for each environment.

## Dev Environment Resources

When you run `terraform apply` in `environments/dev/`, the following AWS resources will be created:

### Networking Module (10 resources)

1. **VPC** (`aws_vpc.main`)
   - CIDR: 10.0.0.0/16
   - DNS hostnames: Enabled
   - DNS support: Enabled
   - Tags: dev-vpc, Environment=dev, ManagedBy=terraform

2. **Public Subnet 1** (`aws_subnet.public[0]`)
   - CIDR: 10.0.1.0/24
   - Availability Zone: us-east-1a
   - Auto-assign public IP: Enabled
   - Tags: dev-public-subnet-1

3. **Public Subnet 2** (`aws_subnet.public[1]`)
   - CIDR: 10.0.2.0/24
   - Availability Zone: us-east-1b
   - Auto-assign public IP: Enabled
   - Tags: dev-public-subnet-2

4. **Private Subnet 1** (`aws_subnet.private[0]`)
   - CIDR: 10.0.3.0/24
   - Availability Zone: us-east-1a
   - Tags: dev-private-subnet-1

5. **Private Subnet 2** (`aws_subnet.private[1]`)
   - CIDR: 10.0.4.0/24
   - Availability Zone: us-east-1b
   - Tags: dev-private-subnet-2

6. **Internet Gateway** (`aws_internet_gateway.main`)
   - Attached to VPC
   - Tags: dev-igw

7. **Elastic IP** (`aws_eip.nat`)
   - Domain: vpc
   - For NAT Gateway
   - Tags: dev-nat-eip

8. **NAT Gateway** (`aws_nat_gateway.main`)
   - Subnet: Public Subnet 1
   - Elastic IP: Attached
   - Tags: dev-nat-gateway

9. **Public Route Table** (`aws_route_table.public`)
   - Route: 0.0.0.0/0 → Internet Gateway
   - Associated with: Public Subnets 1 & 2
   - Tags: dev-public-rt

10. **Private Route Table** (`aws_route_table.private`)
    - Route: 0.0.0.0/0 → NAT Gateway
    - Associated with: Private Subnets 1 & 2
    - Tags: dev-private-rt

### Compute Module (15 resources)

11. **ECS Cluster** (`aws_ecs_cluster.main`)
    - Name: dev-cluster
    - Container Insights: Enabled
    - Tags: dev-cluster

12. **IAM Role - ECS Task Execution** (`aws_iam_role.ecs_task_execution_role`)
    - Name: dev-ecs-task-execution-role
    - Assume role: ecs-tasks.amazonaws.com
    - Tags: dev-ecs-task-execution-role

13. **IAM Role Policy Attachment** (`aws_iam_role_policy_attachment.ecs_task_execution_role_policy`)
    - Policy: AmazonECSTaskExecutionRolePolicy (AWS managed)
    - Attached to: ECS Task Execution Role

14. **IAM Role Policy - Parameter Store Access** (`aws_iam_role_policy.ecs_task_execution_parameter_store`)
    - Name: dev-ecs-parameter-store-access
    - Permissions: ssm:GetParameters, ssm:GetParameter, secretsmanager:GetSecretValue
    - Resource: /dev/* parameters

15. **IAM Role - ECS Task** (`aws_iam_role.ecs_task_role`)
    - Name: dev-ecs-task-role
    - Assume role: ecs-tasks.amazonaws.com
    - Tags: dev-ecs-task-role

16. **IAM Role Policy - CloudWatch Logs** (`aws_iam_role_policy.ecs_task_role_policy`)
    - Name: dev-ecs-task-policy
    - Permissions: logs:CreateLogGroup, logs:CreateLogStream, logs:PutLogEvents
    - Resource: /ecs/dev/* log groups

17. **CloudWatch Log Group** (`aws_cloudwatch_log_group.ecs_tasks`)
    - Name: /ecs/dev/dev-service
    - Retention: 7 days
    - Tags: dev-ecs-logs

18. **ECS Task Definition** (`aws_ecs_task_definition.main`)
    - Family: dev-dev-service
    - Network mode: awsvpc
    - Requires compatibilities: FARGATE
    - CPU: 256 (0.25 vCPU)
    - Memory: 512 MB
    - Container: nginx:latest (port 80)
    - Secrets: DB_PASSWORD, API_KEY (from Parameter Store)
    - Execution role: ECS Task Execution Role
    - Task role: ECS Task Role

19. **Security Group - ALB** (`aws_security_group.alb`)
    - Name: dev-alb-sg
    - Ingress: HTTP (80) from 0.0.0.0/0
    - Ingress: HTTPS (443) from 0.0.0.0/0
    - Egress: All traffic
    - Tags: dev-alb-sg

20. **Security Group - ECS Tasks** (`aws_security_group.ecs_tasks`)
    - Name: dev-ecs-tasks-sg
    - Ingress: Port 80 from ALB security group
    - Egress: All traffic
    - Tags: dev-ecs-tasks-sg

21. **Application Load Balancer** (`aws_lb.main`)
    - Name: dev-alb
    - Type: application
    - Scheme: internet-facing
    - Subnets: Public Subnets 1 & 2
    - Security groups: ALB security group
    - Tags: dev-alb

22. **Target Group** (`aws_lb_target_group.main`)
    - Name: dev-tg
    - Port: 80
    - Protocol: HTTP
    - Target type: ip
    - Health check: /health (30s interval, 5s timeout)
    - Deregistration delay: 30s
    - Tags: dev-tg

23. **ALB Listener** (`aws_lb_listener.main`)
    - Port: 80
    - Protocol: HTTP
    - Default action: Forward to target group
    - Tags: dev-alb-listener

24. **ECS Service** (`aws_ecs_service.main`)
    - Name: dev-service
    - Cluster: dev-cluster
    - Task definition: dev-dev-service
    - Desired count: 2
    - Launch type: FARGATE
    - Subnets: Private Subnets 1 & 2
    - Security groups: ECS Tasks security group
    - Load balancer: Connected to target group
    - Deployment circuit breaker: Enabled with rollback
    - Tags: dev-dev-service

25. **Auto Scaling Target** (`aws_appautoscaling_target.ecs_service`)
    - Resource: service/dev-cluster/dev-service
    - Min capacity: 2
    - Max capacity: 10
    - Scalable dimension: ecs:service:DesiredCount

26. **Auto Scaling Policy** (`aws_appautoscaling_policy.ecs_cpu_scaling`)
    - Name: dev-ecs-cpu-scaling
    - Policy type: TargetTrackingScaling
    - Metric: ECSServiceAverageCPUUtilization
    - Target value: 70%
    - Scale-in cooldown: 300s
    - Scale-out cooldown: 60s

### Database Module (3 resources)

27. **DB Subnet Group** (`aws_db_subnet_group.main`)
    - Name: dev-db-subnet-group
    - Subnets: Private Subnets 1 & 2
    - Tags: dev-db-subnet-group

28. **Security Group - RDS** (`aws_security_group.rds`)
    - Name: dev-db-rds-sg
    - Ingress: PostgreSQL (5432) from ECS Tasks security group
    - Egress: All traffic
    - Tags: dev-db-rds-sg

29. **RDS PostgreSQL Instance** (`aws_db_instance.main`)
    - Identifier: dev-db
    - Engine: postgres 14.7
    - Instance class: db.t3.micro
    - Allocated storage: 20 GB
    - Storage type: gp2
    - Storage encrypted: Yes
    - Database name: appdb
    - Master username: dbadmin
    - Multi-AZ: No (Single-AZ for dev)
    - Publicly accessible: No
    - DB subnet group: dev-db-subnet-group
    - Security groups: RDS security group
    - Backup retention: 7 days
    - Backup window: 03:00-04:00
    - Maintenance window: mon:04:00-mon:05:00
    - Deletion protection: No
    - Skip final snapshot: Yes
    - Tags: dev-db

### Storage Module (4 resources)

30. **S3 Bucket** (`aws_s3_bucket.main`)
    - Name: dev-app-storage-{account-id}
    - Tags: dev-storage

31. **S3 Bucket Versioning** (`aws_s3_bucket_versioning.main`)
    - Status: Enabled

32. **S3 Public Access Block** (`aws_s3_bucket_public_access_block.main`)
    - Block public ACLs: Yes
    - Block public policy: Yes
    - Ignore public ACLs: Yes
    - Restrict public buckets: Yes

33. **S3 Server-Side Encryption** (`aws_s3_bucket_server_side_encryption_configuration.main`)
    - Algorithm: AES256

34. **S3 Lifecycle Configuration** (`aws_s3_bucket_lifecycle_configuration.main`)
    - Rule: transition-to-ia-and-glacier
    - Transition to STANDARD_IA: 30 days
    - Transition to GLACIER: 90 days

---

## Total Resources: 34 AWS Resources per Environment

### Resource Summary by Service:

- **VPC/Networking**: 10 resources
  - 1 VPC
  - 4 Subnets (2 public, 2 private)
  - 1 Internet Gateway
  - 1 NAT Gateway
  - 1 Elastic IP
  - 2 Route Tables

- **ECS/Compute**: 16 resources
  - 1 ECS Cluster
  - 1 ECS Service
  - 1 ECS Task Definition
  - 1 Application Load Balancer
  - 1 Target Group
  - 1 ALB Listener
  - 2 Security Groups
  - 1 CloudWatch Log Group
  - 4 IAM Roles/Policies
  - 1 Auto Scaling Target
  - 1 Auto Scaling Policy

- **RDS/Database**: 3 resources
  - 1 RDS PostgreSQL Instance
  - 1 DB Subnet Group
  - 1 Security Group

- **S3/Storage**: 5 resources (1 bucket + 4 configurations)
  - 1 S3 Bucket
  - Versioning configuration
  - Public access block
  - Encryption configuration
  - Lifecycle configuration

---

## Prod Environment Resources

The prod environment creates the same 34 resources with these differences:

### Configuration Differences:

**Networking:**
- VPC CIDR: 10.1.0.0/16 (vs 10.0.0.0/16 in dev)
- Subnet CIDRs: 10.1.x.x (vs 10.0.x.x in dev)

**Compute:**
- Cluster name: prod-cluster
- Service name: prod-service
- Task CPU: 1024 (1 vCPU) - 4x larger than dev
- Task memory: 2048 MB - 4x larger than dev
- Desired count: 3 tasks (vs 2 in dev)
- Log group: /ecs/prod/prod-service

**Database:**
- Identifier: prod-db
- Instance class: db.t3.small (vs db.t3.micro in dev)
- Allocated storage: 100 GB (vs 20 GB in dev)

**Storage:**
- Bucket name: prod-app-storage-{account-id}
- Lifecycle IA: 90 days (vs 30 days in dev)
- Lifecycle Glacier: 180 days (vs 90 days in dev)

---

## Cost Estimation (Approximate Monthly Costs)

### Dev Environment:
- **VPC/Networking**: ~$35/month (NAT Gateway)
- **ECS Fargate**: ~$15/month (2 tasks × 0.25 vCPU × 512 MB)
- **ALB**: ~$20/month
- **RDS db.t3.micro**: ~$15/month
- **S3**: ~$1/month (minimal usage)
- **Data Transfer**: Variable
- **Total**: ~$86/month

### Prod Environment:
- **VPC/Networking**: ~$35/month (NAT Gateway)
- **ECS Fargate**: ~$120/month (3 tasks × 1 vCPU × 2048 MB)
- **ALB**: ~$20/month
- **RDS db.t3.small**: ~$30/month
- **S3**: ~$5/month (higher usage)
- **Data Transfer**: Variable
- **Total**: ~$210/month

**Note**: Costs are estimates and will vary based on actual usage, data transfer, and AWS region.

---

## Resource Dependencies

The resources are created in this order due to dependencies:

1. **Networking Module** (no dependencies)
   - VPC → Subnets → Internet Gateway → NAT Gateway → Route Tables

2. **Compute Module** (depends on Networking)
   - IAM Roles → ECS Cluster → Task Definition → Security Groups → ALB → Target Group → Listener → ECS Service → Auto Scaling

3. **Database Module** (depends on Networking and Compute)
   - DB Subnet Group → Security Group (needs ECS SG) → RDS Instance

4. **Storage Module** (no dependencies)
   - S3 Bucket → Versioning → Public Access Block → Encryption → Lifecycle

---

## Security Features

All resources include these security features:

✅ **Encryption at Rest**: RDS and S3
✅ **Private Subnets**: ECS tasks and RDS
✅ **No Public Access**: S3 buckets, RDS instances
✅ **Least Privilege**: Security groups allow only required traffic
✅ **Secrets Management**: Parameter Store for sensitive data
✅ **Network Isolation**: Public/private subnet separation
✅ **IAM Roles**: No hardcoded credentials
✅ **Logging**: CloudWatch logs for ECS tasks

---

## Outputs

After applying, Terraform will output:

- **vpc_id**: VPC identifier
- **alb_dns_name**: Load balancer endpoint (access your application here)
- **database_endpoint**: RDS connection string (sensitive)
- **storage_bucket_name**: S3 bucket name

---

## Prerequisites Before Applying

Before running `terraform apply`, ensure:

1. ✅ Backend resources created (run `./scripts/bootstrap-backend.sh`)
2. ✅ AWS credentials configured
3. ✅ Parameter Store secrets created:
   - `/dev/app/db_password`
   - `/dev/app/api_key`
4. ✅ Container image available (update `container_image` in terraform.tfvars)
5. ✅ Backend configuration updated with your AWS account ID

---

## Cleanup

To destroy all resources:

```bash
cd environments/dev
terraform destroy
```

This will remove all 34 resources in reverse dependency order.
