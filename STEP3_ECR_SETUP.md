# Step 3: Build and Push Docker Image to AWS ECR

## Commands to Run

```bash
# 1. Create ECR repository
aws ecr create-repository \
  --repository-name cmc-ts-app \
  --region us-east-1 \
  --profile kiro-lab

# 2. Get ECR repository URI
export ECR_REPO_URI=$(aws ecr describe-repositories \
  --repository-names cmc-ts-app \
  --region us-east-1 \
  --profile kiro-lab \
  --query 'repositories[0].repositoryUri' \
  --output text)

echo "ECR Repository URI: $ECR_REPO_URI"

# 3. Build Docker image
cd example-app
docker build -t cmc-ts-app:latest .

# 4. Tag image for ECR
docker tag cmc-ts-app:latest ${ECR_REPO_URI}:latest

# 5. Login to ECR
aws ecr get-login-password \
  --region us-east-1 \
  --profile kiro-lab | \
  docker login \
  --username AWS \
  --password-stdin ${ECR_REPO_URI}

# 6. Push image to ECR
docker push ${ECR_REPO_URI}:latest

# 7. Go back to project root
cd ..

# 8. Update terraform.tfvars with ECR image URI
sed -i.bak "s|container_image = \"nginx:latest\"|container_image = \"${ECR_REPO_URI}:latest\"|g" environments/dev/terraform.tfvars

# 9. Verify the update
grep container_image environments/dev/terraform.tfvars
```

## Expected Output

After running these commands, you should see:
- ECR repository created successfully
- Docker image built (Node.js 18 Alpine with Express app)
- Image pushed to ECR
- `terraform.tfvars` updated with your ECR image URI

## Verification

```bash
# List images in ECR
aws ecr list-images \
  --repository-name cmc-ts-app \
  --region us-east-1 \
  --profile kiro-lab
```

You should see your `latest` tag listed.

---

**Next:** Proceed to Step 4 (Deploy Infrastructure)
