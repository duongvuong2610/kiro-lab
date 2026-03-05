# GitHub Setup Guide

This guide will help you push your code to GitHub and set up CI/CD with GitHub Actions.

## Prerequisites

- GitHub account
- Git installed locally
- GitHub CLI (optional, but recommended)

## Step 1: Initialize Git Repository

```bash
# Initialize git repository
git init

# Check git status
git status
```

## Step 2: Create .gitignore (if not exists)

Create a `.gitignore` file to exclude unnecessary files:

```bash
cat > .gitignore << 'EOF'
# Terraform
.terraform/
*.tfstate
*.tfstate.*
*.tfvars.backup
*.tfplan
.terraform.lock.hcl
crash.log
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# OS
.DS_Store
Thumbs.db

# IDE
.vscode/
.idea/
*.swp
*.swo
*~

# Logs
*.log

# Temporary files
/tmp/
*.tmp

# Environment variables
.env
.env.local

# Node modules (for example-app)
node_modules/
EOF
```

## Step 3: Add and Commit Files

```bash
# Add all files
git add .

# Check what will be committed
git status

# Create initial commit
git commit -m "Initial commit: AWS Terraform infrastructure with ECS, RDS, S3"
```

## Step 4: Create GitHub Repository

### Option A: Using GitHub CLI (Recommended)

```bash
# Install GitHub CLI if not already installed
# macOS: brew install gh
# Windows: winget install GitHub.cli
# Linux: See https://github.com/cli/cli#installation

# Login to GitHub
gh auth login

# Create repository (choose public or private)
gh repo create aws-terraform-infrastructure --public --source=. --remote=origin --description "AWS 3-tier infrastructure with Terraform: VPC, ECS Fargate, RDS PostgreSQL, S3"

# Push code
git push -u origin main
```

### Option B: Using GitHub Web Interface

1. **Go to GitHub:** https://github.com/new

2. **Repository settings:**
   - Repository name: `aws-terraform-infrastructure`
   - Description: `AWS 3-tier infrastructure with Terraform: VPC, ECS Fargate, RDS PostgreSQL, S3`
   - Choose: Public or Private
   - **DO NOT** initialize with README, .gitignore, or license (we already have these)

3. **Click "Create repository"**

4. **Add remote and push:**
   ```bash
   # Add GitHub as remote (replace YOUR_USERNAME)
   git remote add origin https://github.com/YOUR_USERNAME/aws-terraform-infrastructure.git
   
   # Verify remote
   git remote -v
   
   # Push code
   git branch -M main
   git push -u origin main
   ```

## Step 5: Configure GitHub Secrets for CI/CD

The GitHub Actions workflow needs AWS credentials to run Terraform commands.

### 5.1: Go to Repository Settings

1. Navigate to your repository on GitHub
2. Click **Settings** (top right)
3. In left sidebar: **Secrets and variables** → **Actions**
4. Click **New repository secret**

### 5.2: Add AWS Credentials

Add these two secrets:

#### Secret 1: AWS_ACCESS_KEY_ID

- **Name:** `AWS_ACCESS_KEY_ID`
- **Value:** Your AWS access key from the `kiro-lab` profile
  
  To get it:
  ```bash
  # View your credentials
  cat ~/.aws/credentials | grep -A 2 "\[kiro-lab\]"
  ```
  
  Copy the `aws_access_key_id` value

#### Secret 2: AWS_SECRET_ACCESS_KEY

- **Name:** `AWS_SECRET_ACCESS_KEY`
- **Value:** Your AWS secret access key from the `kiro-lab` profile
  
  Copy the `aws_secret_access_key` value from the same credentials file

### 5.3: Verify Secrets

After adding both secrets, you should see:
- ✅ AWS_ACCESS_KEY_ID
- ✅ AWS_SECRET_ACCESS_KEY

## Step 6: Test GitHub Actions Workflow

The workflow (`.github/workflows/terraform-plan.yml`) triggers on pull requests to `main` branch.

### Create a Test Pull Request

```bash
# Create a new branch
git checkout -b test-ci-workflow

# Make a small change (add a comment)
echo "# Test CI workflow" >> environments/dev/main.tf

# Commit and push
git add environments/dev/main.tf
git commit -m "Test: Trigger CI workflow"
git push origin test-ci-workflow
```

### Create Pull Request on GitHub

1. Go to your repository on GitHub
2. You'll see a banner: "test-ci-workflow had recent pushes"
3. Click **Compare & pull request**
4. Add title: "Test: CI workflow validation"
5. Click **Create pull request**

### Check Workflow Execution

1. Go to **Actions** tab in your repository
2. You should see "Terraform Plan" workflow running
3. Click on the workflow to see details

**The workflow will:**
- ✅ Check Terraform formatting
- ✅ Initialize Terraform
- ✅ Validate configuration
- ✅ Generate plan
- ✅ Post plan results as PR comment

### Expected Workflow Steps

```
✓ Checkout code
✓ Setup Terraform
✓ Terraform Format Check
✓ Configure AWS Credentials
✓ Terraform Init (Dev)
✓ Terraform Validate (Dev)
✓ Terraform Plan (Dev)
✓ Post Plan to PR
```

## Step 7: Review and Merge

1. **Review the PR comment** with Terraform plan output
2. **Check that all workflow steps passed** (green checkmarks)
3. If everything looks good, **merge the PR**
4. Delete the test branch

```bash
# After merging, switch back to main and pull
git checkout main
git pull origin main

# Delete local test branch
git branch -d test-ci-workflow
```

## Troubleshooting

### Issue: Workflow fails with "Error configuring AWS credentials"

**Solution:**
- Verify GitHub Secrets are set correctly
- Check that AWS credentials are valid:
  ```bash
  aws sts get-caller-identity --profile kiro-lab
  ```

### Issue: Workflow fails with "Backend initialization failed"

**Solution:**
- Verify S3 bucket exists:
  ```bash
  aws s3 ls --profile kiro-lab | grep terraform-state
  ```
- Verify DynamoDB table exists:
  ```bash
  aws dynamodb list-tables --profile kiro-lab --region us-east-1 | grep terraform-state-lock
  ```

### Issue: "Permission denied" when pushing to GitHub

**Solution:**
- Set up SSH key or use personal access token
- For HTTPS: https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/creating-a-personal-access-token
- For SSH: https://docs.github.com/en/authentication/connecting-to-github-with-ssh

## Next Steps

After GitHub setup is complete:

1. ✅ Backend created (S3 + DynamoDB)
2. ✅ Terraform initialized
3. ✅ Code pushed to GitHub
4. ✅ CI/CD workflow configured

**Next:** Build and push Docker image to ECR (Step 3 in DEPLOYMENT_GUIDE.md)

## Summary Commands

```bash
# Quick setup (all in one)
git init
git add .
git commit -m "Initial commit: AWS Terraform infrastructure"
gh repo create aws-terraform-infrastructure --public --source=. --remote=origin
git push -u origin main

# Then add GitHub Secrets via web interface
# Then test with a PR
```

---

**Repository URL:** `https://github.com/YOUR_USERNAME/aws-terraform-infrastructure`

**CI/CD Status:** Check the Actions tab after creating a PR
