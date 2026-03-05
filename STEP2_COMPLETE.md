# Step 2: GitHub CI/CD Setup - Completion Guide

## What We've Done

✅ **Verified GitHub Repository**
- Repository: https://github.com/duongvuong2610/kiro-lab
- Branch: master
- Commits: 2 commits pushed successfully

✅ **Fixed Backend Configuration**
- Removed `profile = "kiro-lab"` from backend.tf files
- Now compatible with both local development and CI/CD
- Local development: Use `export AWS_PROFILE=kiro-lab`
- CI/CD: Uses AWS credentials from GitHub Secrets

✅ **Created Documentation**
- `GITHUB_CICD_SETUP.md` - Complete CI/CD setup guide
- `STEP2_COMPLETE.md` - This file (completion summary)

## What You Need to Do Now

### 1. Commit and Push the Backend Configuration Fix

```bash
# Add the modified files
git add environments/dev/backend.tf environments/prod/backend.tf
git add GITHUB_CICD_SETUP.md GITHUB_TOKEN_SETUP.md STEP2_COMPLETE.md

# Commit the changes
git commit -m "Fix: Remove profile from backend.tf for CI/CD compatibility"

# Push to GitHub
git push origin master
```

### 2. Add GitHub Secrets (CRITICAL)

Go to: https://github.com/duongvuong2610/kiro-lab/settings/secrets/actions

**Add these two secrets:**

1. **AWS_ACCESS_KEY_ID**
   ```bash
   # Get your access key
   cat ~/.aws/credentials | grep -A 2 "\[kiro-lab\]"
   ```
   Copy the `aws_access_key_id` value

2. **AWS_SECRET_ACCESS_KEY**
   Copy the `aws_secret_access_key` value

**Steps:**
- Click "New repository secret"
- Name: `AWS_ACCESS_KEY_ID`
- Secret: Paste your access key
- Click "Add secret"
- Repeat for `AWS_SECRET_ACCESS_KEY`

### 3. Test the CI/CD Workflow

```bash
# Create a test branch
git checkout -b test-ci-workflow

# Make a small change
echo "# CI/CD Test" >> README.md

# Commit and push
git add README.md
git commit -m "Test: Trigger CI/CD workflow"
git push origin test-ci-workflow
```

Then:
1. Go to https://github.com/duongvuong2610/kiro-lab
2. Click "Compare & pull request"
3. Create the pull request
4. Go to "Actions" tab to watch the workflow run
5. Check the PR for the automated comment with Terraform plan

### 4. Verify Workflow Success

The workflow should show:
- ✅ Terraform Format Check
- ✅ Configure AWS Credentials
- ✅ Terraform Init (Dev)
- ✅ Terraform Validate (Dev)
- ✅ Terraform Plan (Dev)
- ✅ Post Plan to PR

## Commands Summary

```bash
# 1. Commit backend fixes
git add environments/dev/backend.tf environments/prod/backend.tf GITHUB_CICD_SETUP.md GITHUB_TOKEN_SETUP.md STEP2_COMPLETE.md
git commit -m "Fix: Remove profile from backend.tf for CI/CD compatibility"
git push origin master

# 2. Add GitHub Secrets via web interface (see above)

# 3. Test CI/CD
git checkout -b test-ci-workflow
echo "# CI/CD Test" >> README.md
git add README.md
git commit -m "Test: Trigger CI/CD workflow"
git push origin test-ci-workflow

# 4. Create PR on GitHub and verify workflow runs

# 5. After successful test, merge PR and clean up
git checkout master
git pull origin master
git branch -d test-ci-workflow
```

## Troubleshooting

### If workflow fails with "Error configuring AWS credentials"
- Verify GitHub Secrets are added correctly
- Check secret names match exactly: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`

### If workflow fails with "Backend initialization failed"
- Verify S3 bucket exists: `aws s3 ls --profile kiro-lab | grep terraform-state`
- Verify DynamoDB table exists: `aws dynamodb list-tables --profile kiro-lab --region us-east-1`

### If you need to re-initialize Terraform locally
```bash
export AWS_PROFILE=kiro-lab
cd environments/dev
rm -rf .terraform
terraform init
```

## What's Next

After CI/CD is working:

**Step 3:** Build and push Docker image to AWS ECR
**Step 4:** Deploy infrastructure with Terraform
**Step 5:** Test the deployed application

See `QUICK_START.md` for detailed commands.

---

## Current Status

✅ Step 1: Terraform backend created
✅ Step 2: GitHub CI/CD setup (in progress - add secrets and test)
⏳ Step 3: Build Docker image
⏳ Step 4: Deploy infrastructure
⏳ Step 5: Test application

**Repository:** https://github.com/duongvuong2610/kiro-lab
**Actions:** https://github.com/duongvuong2610/kiro-lab/actions
**AWS Account:** 471112857175
