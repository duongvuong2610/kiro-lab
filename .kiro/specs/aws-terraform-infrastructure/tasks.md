# Implementation Plan: AWS Terraform Infrastructure

## Overview

This implementation plan breaks down the AWS 3-tier containerized application infrastructure into discrete coding tasks. The infrastructure will be built using Terraform modules for networking, compute, database, and storage components, with environment-specific configurations for dev and prod. The implementation includes CI/CD pipeline setup and Kiro IDE integration for accelerated development with automatic validation and enforced coding standards.

## Tasks

- [x] 1. Set up project structure and Terraform backend configuration
  - Create root directory structure: modules/, environments/, .github/workflows/, .kiro/
  - Create backend S3 bucket and DynamoDB table for state management (manual AWS setup or separate bootstrap script)
  - Document backend setup procedures in README.md
  - _Requirements: 5.1, 5.2, 6.1, 6.2_

- [ ] 2. Implement networking module
  - [x] 2.1 Create networking module structure and variable definitions
    - Create modules/networking/ directory
    - Create variables.tf with VPC CIDR, environment, availability zones, subnet CIDRs variables
    - Create outputs.tf with VPC ID, subnet IDs, gateway IDs outputs
    - _Requirements: 1.1, 1.7, 1.8, 1.9_
  
  - [x] 2.2 Implement VPC and subnet resources
    - Create VPC resource with configurable CIDR block
    - Create 2 public subnets across 2 availability zones
    - Create 2 private subnets across 2 availability zones
    - Add resource tags for environment and management tracking
    - _Requirements: 1.1, 1.2, 1.3_
  
  - [x] 2.3 Implement gateways and routing
    - Create Internet Gateway attached to VPC
    - Create NAT Gateway in public subnet with Elastic IP
    - Create public route table with route to Internet Gateway
    - Create private route table with route to NAT Gateway
    - Associate route tables with appropriate subnets
    - _Requirements: 1.4, 1.5, 1.6_
  
  - [ ]* 2.4 Write property tests for networking module
    - **Property 1: VPC Creation with Configurable CIDR**
    - **Property 2: Multi-AZ Public Subnet Distribution**
    - **Property 3: Multi-AZ Private Subnet Distribution**
    - **Property 4: Internet Gateway Attachment**
    - **Property 5: NAT Gateway in Public Subnet**
    - **Property 6: Route Table Configuration**
    - **Property 7: Module Output Completeness**
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7**

- [ ] 3. Implement compute module
  - [x] 3.1 Create compute module structure and variable definitions
    - Create modules/compute/ directory
    - Create variables.tf with cluster name, service name, task configuration, networking variables
    - Create outputs.tf with cluster ID, service name, ALB DNS, security group IDs
    - _Requirements: 2.9, 2.10_
  
  - [x] 3.2 Implement ECS cluster and IAM roles
    - Create ECS Fargate cluster with Container Insights enabled
    - Create IAM role for task execution with Parameter Store access
    - Create IAM role for task with application permissions
    - _Requirements: 2.1, 2.2_
  
  - [x] 3.3 Implement ECS task definition and service
    - Create task definition with container configuration
    - Configure secrets from Parameter Store (not hardcoded)
    - Create ECS service with desired_count=2
    - Enable deployment circuit breaker
    - Configure service to use private subnets
    - _Requirements: 2.2, 2.3, 2.4, 15.3_
  
  - [x] 3.4 Implement Application Load Balancer
    - Create ALB in public subnets
    - Create target group with /health health check endpoint
    - Create ALB listener on port 80
    - Create security group for ALB allowing HTTP/HTTPS from internet
    - _Requirements: 2.5, 2.6_
  
  - [x] 3.5 Implement security groups and auto-scaling
    - Create security group for ECS tasks allowing traffic from ALB
    - Configure security group rules for ALB to ECS communication
    - Create auto-scaling target for ECS service
    - Create auto-scaling policy with 70% CPU target tracking
    - _Requirements: 2.7, 2.8_
  
  - [ ]* 3.6 Write property tests for compute module
    - **Property 8: ECS Cluster with Container Insights**
    - **Property 9: Task Definition with Parameter Store Secrets**
    - **Property 10: ECS Service Desired Count**
    - **Property 11: Deployment Circuit Breaker**
    - **Property 12: ALB with Target Group**
    - **Property 13: Health Check Endpoint Configuration**
    - **Property 14: Auto-Scaling Policy Configuration**
    - **Property 15: Security Group Rules for ALB to ECS**
    - **Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8**

- [x] 4. Checkpoint - Verify networking and compute modules
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 5. Implement database module
  - [x] 5.1 Create database module structure and variable definitions
    - Create modules/database/ directory
    - Create variables.tf with RDS configuration, networking, and security variables
    - Create outputs.tf with endpoint, address, port, database name outputs
    - _Requirements: 3.7, 3.8_
  
  - [x] 5.2 Implement RDS PostgreSQL instance
    - Create DB subnet group using private subnets
    - Create RDS PostgreSQL instance in Single-AZ configuration
    - Enable encryption at rest (storage_encrypted = true)
    - Use small instance type suitable for development (db.t3.micro)
    - Configure master username and password (from variables)
    - _Requirements: 3.1, 3.2, 3.3, 3.5, 14.1_
  
  - [x] 5.3 Implement RDS security group
    - Create security group for RDS
    - Add ingress rule allowing PostgreSQL port (5432) only from ECS task security group
    - Ensure no public access to RDS
    - _Requirements: 3.4, 15.1_
  
  - [ ]* 5.4 Write property tests for database module
    - **Property 16: RDS PostgreSQL Configuration**
    - **Property 17: RDS Encryption at Rest**
    - **Property 18: RDS in Private Subnets**
    - **Property 19: RDS Security Group Restriction**
    - **Property 20: Development-Appropriate Instance Types**
    - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 15.1**

- [ ] 6. Implement storage module
  - [x] 6.1 Create storage module structure and variable definitions
    - Create modules/storage/ directory
    - Create variables.tf with bucket name, environment, lifecycle configuration variables
    - Create outputs.tf with bucket name, ARN, domain name outputs
    - _Requirements: 4.7, 4.8_
  
  - [x] 6.2 Implement S3 bucket with security controls
    - Create S3 bucket with unique name
    - Enable versioning
    - Block all public access (all four settings)
    - Enable server-side encryption
    - Add resource tags
    - _Requirements: 4.1, 4.4, 4.5, 15.2_
  
  - [x] 6.3 Implement S3 lifecycle policies
    - Create lifecycle rule transitioning objects to Infrequent Access after 30 days
    - Create lifecycle rule transitioning objects to Glacier after 90 days
    - _Requirements: 4.2, 4.3, 14.5_
  
  - [ ]* 6.4 Write property tests for storage module
    - **Property 21: S3 Versioning Enabled**
    - **Property 22: S3 Lifecycle Policy for Infrequent Access**
    - **Property 23: S3 Lifecycle Policy for Glacier**
    - **Property 24: S3 Public Access Block**
    - **Property 25: S3 Encryption Enabled**
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 15.2**

- [x] 7. Checkpoint - Verify all modules are complete
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 8. Implement dev environment configuration
  - [x] 8.1 Create dev environment structure
    - Create environments/dev/ directory
    - _Requirements: 5.1_
  
  - [x] 8.2 Create dev environment main configuration
    - Create main.tf with provider configuration
    - Add module blocks for networking, compute, database, storage
    - Wire module outputs to dependent module inputs
    - Use dev-specific naming (dev-cluster, dev-service, dev-db)
    - _Requirements: 5.3, 5.6_
  
  - [x] 8.3 Create dev environment variables and backend
    - Create terraform.tfvars with dev-specific values (small instance types, dev CIDR ranges)
    - Create backend.tf with S3 backend configuration for dev state
    - Enable encryption and versioning in backend config
    - Configure DynamoDB table for state locking
    - _Requirements: 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5, 14.4_
  
  - [ ]* 8.4 Write property tests for dev environment
    - **Property 26: Environment Configuration Files**
    - **Property 27: Module References in Environment**
    - **Property 28: S3 Backend Configuration**
    - **Property 29: DynamoDB State Locking**
    - **Property 31: State File Encryption**
    - **Property 32: Backend Configuration per Environment**
    - **Validates: Requirements 5.3, 5.4, 5.5, 5.6, 6.1, 6.2, 6.4, 6.5**

- [ ] 9. Implement prod environment configuration
  - [x] 9.1 Create prod environment structure
    - Create environments/prod/ directory
    - _Requirements: 5.2_
  
  - [x] 9.2 Create prod environment main configuration
    - Create main.tf with provider configuration
    - Add module blocks for networking, compute, database, storage
    - Wire module outputs to dependent module inputs
    - Use prod-specific naming (prod-cluster, prod-service, prod-db)
    - _Requirements: 5.3, 5.6_
  
  - [x] 9.3 Create prod environment variables and backend
    - Create terraform.tfvars with prod-specific values (production-grade instance types)
    - Create backend.tf with S3 backend configuration for prod state (separate from dev)
    - Enable encryption and versioning in backend config
    - Configure DynamoDB table for state locking
    - _Requirements: 5.4, 5.5, 6.1, 6.2, 6.3, 6.4, 6.5_

- [ ] 10. Implement CI/CD pipeline
  - [x] 10.1 Create GitHub Actions workflow for Terraform validation
    - Create .github/workflows/terraform-plan.yml
    - Configure workflow to trigger on pull requests to main branch
    - Add terraform fmt -check step
    - Add terraform validate step
    - Add terraform plan step
    - Configure AWS credentials from GitHub secrets
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.7_
  
  - [x] 10.2 Add plan result posting to PR
    - Add step to post terraform plan output as PR comment
    - Configure workflow to fail if any validation step fails
    - _Requirements: 7.5, 7.6_
  
  - [ ]* 10.3 Write property tests for CI/CD pipeline
    - **Property 33: CI/CD Workflow Trigger**
    - **Property 34: CI/CD Validation Steps**
    - **Validates: Requirements 7.1, 7.2, 7.3, 7.4, 7.5**

- [x] 11. Checkpoint - Verify environments and CI/CD
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 12. Implement Kiro IDE integration - Agent hooks
  - [x] 12.1 Create Kiro hooks directory and agent hook
    - Create .kiro/hooks/ directory
    - Create agent hook configuration for Terraform file validation
    - Configure hook to trigger on .tf file save
    - Add terraform validate command to hook
    - Add terraform fmt command to hook
    - Configure error display for validation failures
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 9.5_
  
  - [ ]* 12.2 Write property tests for agent hooks
    - **Property 36: Agent Hook Validation Commands**
    - **Property 37: Agent Hook Error Display**
    - **Property 38: Agent Hook Automatic Execution**
    - **Validates: Requirements 9.2, 9.3, 9.4, 9.5**

- [ ] 13. Implement Kiro IDE integration - Steering file
  - [x] 13.1 Create Kiro steering directory and standards file
    - Create .kiro/steering/ directory
    - Create terraform-standards.md steering file
    - Define naming conventions for AWS resources
    - Define tagging strategy for all resources
    - Define security rules: no wildcard IAM permissions
    - Define security rules: encryption required for data storage
    - Define security rules: private subnets required for databases
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 10.6, 10.7_
  
  - [ ]* 13.2 Write property tests for steering file
    - **Property 39: Steering File Security Rules**
    - **Property 40: Steering File Standards**
    - **Validates: Requirements 10.2, 10.3, 10.4, 10.5, 10.6**

- [ ] 14. Implement Kiro IDE integration - MCP servers
  - [x] 14.1 Create MCP configuration file
    - Create .kiro/mcp.json
    - Configure terraform-mcp-server for Terraform command execution
    - Configure github MCP server for GitHub API interaction
    - Add environment variable placeholders for authentication
    - _Requirements: 11.1, 11.2, 11.3, 11.4, 11.5_
  
  - [ ]* 14.2 Write property tests for MCP configuration
    - **Property 41: MCP Server Configuration**
    - **Validates: Requirements 11.2, 11.3**

- [ ] 15. Create documentation and example application configuration
  - [x] 15.1 Create README with setup instructions
    - Document prerequisites (Terraform, AWS CLI, AWS account)
    - Document backend setup procedures
    - Document how to deploy dev environment
    - Document how to deploy prod environment
    - Document cost optimization procedures (stopping/starting resources)
    - _Requirements: 14.3_
  
  - [x] 15.2 Document application deployment
    - Document container image requirements
    - Document health check endpoint requirement (/health)
    - Document Parameter Store secret setup
    - Provide example of simple web application container
    - _Requirements: 13.1, 13.2, 13.3, 13.4_
  
  - [x] 15.3 Create example container application
    - Create simple web application that displays "Welcome to CMC TS"
    - Implement /health endpoint
    - Create Dockerfile
    - Document how to build and push to Docker Hub or ECR
    - _Requirements: 13.2, 13.4_

- [ ] 16. Final integration and validation
  - [x] 16.1 Validate complete project structure
    - Verify all required directories exist
    - Verify all required files exist (variables.tf, outputs.tf, etc.)
    - Run terraform fmt on all .tf files
    - Run terraform validate on all modules
    - _Requirements: 1.8, 1.9, 2.9, 2.10, 3.7, 3.8, 4.7, 4.8_
  
  - [ ]* 16.2 Write property test for project structure
    - **Property 44: Project Structure Completeness**
    - **Validates: Requirements 1.8, 1.9, 2.9, 2.10, 3.7, 3.8, 4.7, 4.8, 5.1, 5.2, 7.7, 9.1, 10.1, 11.1**
  
  - [ ]* 16.3 Run comprehensive property-based tests
    - Execute all property tests across all modules
    - Verify security properties (encryption, private subnets, no wildcards)
    - Verify configuration properties (files, outputs, backends)
    - Generate test report
    - **Property 43: IAM Policy Wildcard Prohibition**
    - **Validates: Requirements 15.6**

- [x] 17. Final checkpoint - Complete infrastructure ready for deployment
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation throughout implementation
- Property tests validate universal correctness properties from the design document
- The infrastructure uses Terraform/HCL as the implementation language
- All modules follow consistent structure: variables.tf, main.tf (implied), outputs.tf
- Security controls are enforced through steering file and validated through property tests
- CI/CD pipeline provides continuous validation of infrastructure changes
- Kiro IDE integration accelerates development with automatic validation and AI assistance
