# CMC TS Example Application

A minimal web application for demonstrating the AWS Terraform infrastructure deployment.

## Features

- Displays "Welcome to CMC TS" on the root endpoint (`/`)
- Provides health check endpoint at `/health`
- Lightweight Node.js application using Express
- Containerized with Docker for easy deployment

## Application Endpoints

- `GET /` - Returns "Welcome to CMC TS" message
- `GET /health` - Returns JSON health status: `{"status": "healthy"}`

## Local Development

### Prerequisites

- Node.js 18 or higher
- npm

### Running Locally

```bash
# Install dependencies
npm install

# Start the application
npm start

# The application will be available at http://localhost:80
```

### Testing Endpoints

```bash
# Test root endpoint
curl http://localhost:80

# Test health endpoint
curl http://localhost:80/health
```

## Docker Build and Deployment

### Building the Docker Image

```bash
# Build the image
docker build -t cmc-ts-app:latest .

# Verify the image was created
docker images | grep cmc-ts-app
```

### Running the Container Locally

```bash
# Run the container
docker run -p 8080:80 cmc-ts-app:latest

# Test the application
curl http://localhost:8080
curl http://localhost:8080/health
```

### Pushing to Docker Hub

```bash
# Login to Docker Hub
docker login

# Tag the image with your Docker Hub username
docker tag cmc-ts-app:latest YOUR_DOCKERHUB_USERNAME/cmc-ts-app:latest

# Push to Docker Hub
docker push YOUR_DOCKERHUB_USERNAME/cmc-ts-app:latest
```

### Pushing to Amazon ECR

```bash
# Authenticate Docker to your ECR registry
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Create ECR repository (if it doesn't exist)
aws ecr create-repository --repository-name cmc-ts-app --region us-east-1

# Tag the image for ECR
docker tag cmc-ts-app:latest YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app:latest

# Push to ECR
docker push YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app:latest
```

## Deploying to ECS

### Update Terraform Configuration

After pushing your image to Docker Hub or ECR, update the `container_image` variable in your environment's `terraform.tfvars`:

**For Docker Hub:**
```hcl
container_image = "YOUR_DOCKERHUB_USERNAME/cmc-ts-app:latest"
```

**For ECR:**
```hcl
container_image = "YOUR_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/cmc-ts-app:latest"
```

### Deploy Infrastructure

```bash
# Navigate to your environment directory
cd environments/dev

# Initialize Terraform (if not already done)
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply

# Get the ALB DNS name from outputs
terraform output alb_dns_name
```

### Verify Deployment

```bash
# Get the ALB DNS name
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test the application
curl http://$ALB_DNS
# Expected output: Welcome to CMC TS

# Test the health endpoint
curl http://$ALB_DNS/health
# Expected output: {"status":"healthy"}
```

## Environment Variables

The application supports the following environment variables:

- `PORT` - Port number for the application (default: 80)

To set environment variables in ECS, update the task definition in the compute module's `main.tf`:

```hcl
environment = [
  {
    name  = "PORT"
    value = "80"
  }
]
```

## Monitoring

The application logs to stdout, which is captured by CloudWatch Logs when running in ECS. View logs in the AWS Console:

1. Navigate to ECS → Clusters → Your Cluster → Tasks
2. Click on a running task
3. Click on the "Logs" tab to view CloudWatch logs

## Troubleshooting

### Container Won't Start

- Check CloudWatch logs for error messages
- Verify the container image exists and is accessible
- Ensure IAM task execution role has permissions to pull from ECR (if using ECR)

### Health Check Failing

- Verify the `/health` endpoint returns 200 status code
- Check that the container port (80) matches the target group configuration
- Review security group rules to ensure ALB can reach ECS tasks

### Application Not Accessible

- Verify ALB is in "active" state
- Check target group health status
- Ensure at least one ECS task is running
- Verify security group rules allow inbound traffic to ALB

## Security Considerations

- The application runs on port 80 (HTTP) for simplicity
- For production, configure HTTPS on the ALB with SSL/TLS certificates
- Use AWS Certificate Manager (ACM) for SSL certificates
- Configure ALB listener to redirect HTTP to HTTPS

## Cost Optimization

- Use smaller ECS task sizes for development (256 CPU, 512 MB memory)
- Scale down desired_count to 1 for non-production environments
- Stop ECS services when not in use to avoid charges
- Use ECR lifecycle policies to clean up old images

## Next Steps

- Add application-specific environment variables
- Integrate with RDS database using connection details from Terraform outputs
- Add S3 integration for file storage
- Implement application logging and monitoring
- Add unit and integration tests
