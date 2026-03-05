# GitHub CI/CD Setup - Step by Step

Your code is already pushed to GitHub! Now let's complete the CI/CD setup.

**Repository:** https://github.com/duongvuong2610/kiro-lab

## Current Status

✅ Git repository initialized
✅ Code pushed to GitHub (master branch)
✅ GitHub Actions workflow configured (`.github/workflows/terraform-plan.yml`)

## Step 1: Add GitHub Secrets for AWS Credentials

The GitHub Actions workflow needs AWS credentials to run Terraform commands.

### 1.1: Get Your AWS Credentials

First, retrieve your AWS credentials from the `kiro-lab` profile:

```bash
# View your AWS credentials
cat ~/.aws/credentials
```

Look for the `[kiro-lab]` section and copy:
- `aws_access_key_id`
- `aws_secret_access_key`

### 1.2: Add Secrets to GitHub

1. **Go to your repository on GitHub:**
   https://github.com/duongvuong2610/kiro-lab

2. **Navigate to Settings:**
   - Click **Settings** (top right of repository page)

3. **Go to Secrets:**
   - In the left sidebar, click **Secrets and variables** → **Actions**

4. **Add First Secret:**
   - Click **New repository secret**
   - Name: `AWS_ACCESS_KEY_ID`
   - Secret: Paste your `aws_access_key_id` value
   - Click **Add secret**

5. **Add Second Secret:**
   - Click **New repository secret** again
   - Name: `AWS_SECRET_ACCESS_KEY`
   - Secret: Paste your `aws_secret_access_key` value
   - Click **Add secret**

### 1.3: Verify Secrets

After adding both secrets, you should see:
- ✅ AWS_ACCESS_KEY_ID (Updated X seconds ago)
- ✅ AWS_SECRET_ACCESS_KEY (Updated X seconds ago)

## Step 2: Test the CI/CD Workflow

Now let's test the GitHub Actions workflow by creating a pull request.

### 2.1: Create a Test Branch

```bash
# Create and switch to a new branch
git checkout -b test-ci-workflow

# Make a small change to trigger the workflow
echo "# CI/CD Test" >> README.md

# Stage and commit the change
git add README.md
git commit -m "Test: Trigger CI/CD workflow"

# Push the branch to GitHub
git push origin test-ci-workflow
```

### 2.2: Create a Pull Request

1. **Go to your repository on GitHub:**
   https://github.com/duongvuong2610/kiro-lab

2. **You'll see a banner:**
   "test-ci-workflow had recent pushes X minutes ago"

3. **Click "Compare & pull request"**

4. **Fill in PR details:**
   - Title: `Test: CI/CD workflow validation`
   - Description: `Testing GitHub Actions workflow for Terraform validation`

5. **Click "Create pull request"**

### 2.3: Monitor Workflow Execution

1. **Go to the Actions tab:**
   https://github.com/duongvuong2610/kiro-lab/actions

2. **You should see:**
   - Workflow name: "Terraform Plan"
   - Status: Running (yellow circle) or Completed (green checkmark)

3. **Click on the workflow run** to see details

### 2.4: Expected Workflow Steps

The workflow should execute these steps:

```
✓ Checkout code
✓ Setup Terraform
✓ Terraform Format Check
✓ Configure AWS Credentials
✓ Terraform Init (Dev)
✓ Terraform Validate (Dev)
✓ Terraform Plan (Dev)
✓ Post Plan to PR
✓ Check for Failures
```

### 2.5: Review PR Comment

1. **Go back to your Pull Request**

2. **You should see a comment** from GitHub Actions with:
   - Terraform Format status
   - Terraform Init status
   - Terraform Validate status
   - Terraform Plan status
   - Expandable section with full plan output

### 2.6: Merge or Close the PR

If all checks pass:

**Option A: Merge the PR**
```bash
# After merging on GitHub, update your local master branch
git checkout master
git pull origin master

# Delete the test branch
git branch -d test-ci-workflow
```

**Option B: Close without merging**
```bash
# Just switch back to master
git checkout master

# Delete the test branch
git branch -D test-ci-workflow
```

## Step 3: Verify CI/CD is Working

### Check Workflow Status

```bash
# You can also check workflow status via GitHub CLI (if installed)
gh run list --repo duongvuong2610/kiro-lab

# View details of the latest run
gh run view --repo duongvuong2610/kiro-lab
```

### What the Workflow Does

Every time you create a PR to `master` that modifies Terraform files:

1. **Format Check:** Ensures all `.tf` files are properly formatted
2. **Init:** Initializes Terraform with the S3 backend
3. **Validate:** Checks Terraform syntax and configuration
4. **Plan:** Generates an execution plan showing what will change
5. **Comment:** Posts the plan results as a PR comment
6. **Fail:** Blocks merge if any validation step fails

## Troubleshooting

### Issue: Workflow fails with "Error configuring AWS credentials"

**Cause:** GitHub Secrets not set or incorrect

**Solution:**
1. Go to Settings → Secrets and variables → Actions
2. Verify both secrets exist:
   - AWS_ACCESS_KEY_ID
   - AWS_SECRET_ACCESS_KEY
3. If missing, add them following Step 1.2
4. Re-run the workflow

### Issue: Workflow fails with "Backend initialization failed"

**Cause:** Terraform backend (S3/DynamoDB) not accessible

**Solution:**
1. Verify S3 bucket exists:
   ```bash
   aws s3 ls --profile kiro-lab | grep terraform-state
   ```

2. Verify DynamoDB table exists:
   ```bash
   aws dynamodb list-tables --profile kiro-lab --region us-east-1 | grep terraform-state-lock
   ```

3. Check IAM permissions for the AWS credentials in GitHub Secrets

### Issue: Workflow fails with "terraform init" error about profile

**Cause:** Backend configuration references `profile = "kiro-lab"` which doesn't exist in GitHub Actions

**Solution:** Remove the `profile` line from backend.tf files for CI/CD compatibility:

```bash
# The backend.tf should not have profile for CI/CD
# GitHub Actions uses AWS credentials from environment variables
```

Let me fix this for you:

## Step 4: Fix Backend Configuration for CI/CD

The backend configuration should not include `profile` for GitHub Actions compatibility.

### Update environments/dev/backend.tf

Remove the `profile` line:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-471112857175"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    # profile = "kiro-lab"  # Remove this line for CI/CD
  }
}
```

### Update environments/prod/backend.tf

Same change for prod:

```hcl
terraform {
  backend "s3" {
    bucket         = "terraform-state-471112857175"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    # profile = "kiro-lab"  # Remove this line for CI/CD
  }
}
```

### For Local Development

When running Terraform locally, use environment variable:

```bash
# Set AWS profile for local development
export AWS_PROFILE=kiro-lab

# Then run Terraform commands
cd environments/dev
terraform init
terraform plan
```

## Summary

After completing these steps:

✅ **GitHub Secrets configured** with AWS credentials
✅ **CI/CD workflow tested** with a pull request
✅ **Backend configuration fixed** for CI/CD compatibility
✅ **Workflow validates** all Terraform changes automatically

## Next Steps

Now that CI/CD is set up, you can proceed to:

**Step 3:** Build and push Docker image to AWS ECR
**Step 4:** Deploy infrastructure with Terraform
**Step 5:** Test the deployed application

See `QUICK_START.md` for the next commands to run.

---

**Repository:** https://github.com/duongvuong2610/kiro-lab
**Workflow:** https://github.com/duongvuong2610/kiro-lab/actions
**AWS Account:** 471112857175
**AWS Profile:** kiro-lab
