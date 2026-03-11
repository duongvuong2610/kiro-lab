# AWS 3-Tier Architecture Diagram

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Internet / Users                                │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │ HTTP/HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         Internet Gateway (IGW)                               │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16) - us-east-1                            │
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    PUBLIC SUBNETS (2 AZs)                           │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────┐      │    │
│  │  │  Application Load Balancer (ALB)                         │      │    │
│  │  │  - Health checks: /health                                │      │    │
│  │  │  - Target Group: ECS Tasks                               │      │    │
│  │  └────────────────────┬─────────────────────────────────────┘      │    │
│  │                       │                                             │    │
│  │  ┌────────────────────┴─────────────────────────────────────┐      │    │
│  │  │  NAT Gateway                                             │      │    │
│  │  │  - Elastic IP attached                                   │      │    │
│  │  └──────────────────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                 │                                            │
│                                 │ Forward traffic                            │
│                                 ▼                                            │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                   PRIVATE SUBNETS (2 AZs)                           │    │
│  │                                                                      │    │
│  │  ┌──────────────────────────────────────────────────────────┐      │    │
│  │  │  ECS Fargate Cluster (dev-cluster)                       │      │    │
│  │  │                                                           │      │    │
│  │  │  ┌─────────────────┐      ┌─────────────────┐           │      │    │
│  │  │  │  ECS Task 1     │      │  ECS Task 2     │           │      │    │
│  │  │  │  ─────────────  │      │  ─────────────  │           │      │    │
│  │  │  │  Node.js App    │      │  Node.js App    │           │      │    │
│  │  │  │  Port: 3000     │      │  Port: 3000     │           │      │    │
│  │  │  │  CPU: 256       │      │  CPU: 256       │           │      │    │
│  │  │  │  Memory: 512MB  │      │  Memory: 512MB  │           │      │    │
│  │  │  └────────┬────────┘      └────────┬────────┘           │      │    │
│  │  │           │                        │                     │      │    │
│  │  │           └────────────┬───────────┘                     │      │    │
│  │  └────────────────────────┼─────────────────────────────────┘      │    │
│  │                           │                                         │    │
│  │                           │ PostgreSQL (5432)                       │    │
│  │                           ▼                                         │    │
│  │  ┌──────────────────────────────────────────────────────────┐      │    │
│  │  │  RDS PostgreSQL (dev-db)                                 │      │    │
│  │  │  - Instance: db.t3.micro                                 │      │    │
│  │  │  - Storage: 20GB (encrypted)                             │      │    │
│  │  │  - Multi-AZ: No (dev environment)                        │      │    │
│  │  │  - Backup: 7 days retention                              │      │    │
│  │  └──────────────────────────────────────────────────────────┘      │    │
│  └────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────┐
│                         AWS SUPPORTING SERVICES                              │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │  S3 Bucket       │  │  ECR Repository  │  │  CloudWatch Logs │          │
│  │  ──────────────  │  │  ──────────────  │  │  ──────────────  │          │
│  │  - Versioning    │  │  cmc-ts-app      │  │  /ecs/dev-task   │          │
│  │  - Encryption    │  │  - Image: latest │  │  - Retention: 7d │          │
│  │  - Lifecycle     │  │  - Arch: amd64   │  │                  │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
│                                                                              │
│  ┌──────────────────┐  ┌──────────────────┐  ┌──────────────────┐          │
│  │  Parameter Store │  │  IAM Roles       │  │  Auto Scaling    │          │
│  │  ──────────────  │  │  ──────────────  │  │  ──────────────  │          │
│  │  - db_password   │  │  - Task Exec     │  │  - Min: 2 tasks  │          │
│  │  - api_key       │  │  - Task Role     │  │  - Max: 10 tasks │          │
│  │  (SecureString)  │  │                  │  │  - CPU: 70%      │          │
│  └──────────────────┘  └──────────────────┘  └──────────────────┘          │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Traffic Flow

### Inbound Traffic (User → Application)
1. User sends HTTP request to ALB DNS
2. Internet Gateway routes traffic to ALB in public subnet
3. ALB performs health check on `/health` endpoint
4. ALB forwards request to healthy ECS task in private subnet
5. ECS task processes request and returns response

### Outbound Traffic (Application → Internet)
1. ECS task in private subnet initiates outbound connection
2. Traffic routes through NAT Gateway in public subnet
3. NAT Gateway forwards to Internet Gateway
4. Response returns through same path

### Database Access
1. ECS tasks connect to RDS PostgreSQL on port 5432
2. Connection stays within private subnets
3. Security group allows only ECS → RDS traffic
4. Credentials retrieved from Parameter Store

## Security Architecture

### Network Security
- **Public Subnets**: ALB and NAT Gateway only
- **Private Subnets**: ECS tasks and RDS (no direct internet access)
- **Security Groups**:
  - ALB SG: Allow 80/443 from internet
  - ECS SG: Allow traffic only from ALB
  - RDS SG: Allow 5432 only from ECS

### Data Security
- **Encryption at Rest**: RDS and S3 encrypted with AES256
- **Secrets Management**: Credentials in Parameter Store (SecureString)
- **S3 Security**: Public access blocked, versioning enabled
- **IAM**: Least-privilege roles for task execution and application

### High Availability
- **Multi-AZ**: Resources distributed across 2 availability zones
- **Auto Scaling**: ECS tasks scale 2-10 based on CPU (70% target)
- **Health Checks**: ALB monitors `/health` endpoint (30s interval)
- **Circuit Breaker**: Automatic rollback on failed deployments

## Resource Summary

| Component | Resource | Configuration |
|-----------|----------|---------------|
| **Networking** | VPC | 10.0.0.0/16, 2 AZs |
| | Public Subnets | 10.0.1.0/24, 10.0.2.0/24 |
| | Private Subnets | 10.0.3.0/24, 10.0.4.0/24 |
| | NAT Gateway | 1 (in AZ-1) |
| **Compute** | ECS Cluster | Fargate, Container Insights |
| | ECS Tasks | 2-10 tasks, 256 CPU, 512MB RAM |
| | ALB | Application Load Balancer |
| **Database** | RDS PostgreSQL | db.t3.micro, 20GB, Single-AZ |
| **Storage** | S3 | Versioned, encrypted, lifecycle |
| **Monitoring** | CloudWatch | Logs, metrics, alarms |
| **Security** | IAM | Task execution + task roles |
| | Parameter Store | Encrypted secrets |

## Cost Optimization

### Development Environment
- RDS: Single-AZ (Multi-AZ for production)
- ECS: Minimal CPU/memory allocation
- NAT: Single gateway (Multi-AZ for production)
- S3: Lifecycle policies (IA after 30d, Glacier after 90d)

### Estimated Monthly Cost
- ECS Fargate: ~$15-20
- RDS t3.micro: ~$15
- NAT Gateway: ~$32
- ALB: ~$16
- **Total: ~$78-83/month**

## Deployment Architecture

```
GitHub Repository (kiro-lab)
         │
         │ Push to branch
         ▼
GitHub Actions Workflow
         │
         ├─ terraform fmt -check
         ├─ terraform validate
         └─ terraform plan
         │
         │ On merge to master
         ▼
Manual terraform apply
         │
         ├─ Create/Update VPC
         ├─ Create/Update ECS
         ├─ Create/Update RDS
         └─ Create/Update S3
         │
         ▼
ECS pulls image from ECR
         │
         ▼
Application Running
```

## Monitoring and Logging

### CloudWatch Logs
- **Log Group**: `/ecs/dev-task`
- **Retention**: 7 days
- **Streams**: One per ECS task

### CloudWatch Metrics
- ECS service CPU/memory utilization
- ALB request count and latency
- RDS connections and performance
- Auto-scaling events

### Health Checks
- **ALB Health Check**: `/health` endpoint
- **Interval**: 30 seconds
- **Healthy Threshold**: 2 consecutive successes
- **Unhealthy Threshold**: 2 consecutive failures

## Disaster Recovery

### Backup Strategy
- **RDS**: Automated daily backups (7-day retention)
- **S3**: Versioning enabled
- **Terraform State**: Versioned in S3 with DynamoDB locking

### Recovery Procedures
1. RDS: Point-in-time restore from automated backups
2. S3: Restore previous object versions
3. Infrastructure: `terraform apply` from version control

