# GitHub Actions Workflow Fix Applied

## Issue Identified

The GitHub Actions workflow "Terraform Plan" was failing with the following error:

```
RequestError [HttpError]: Resource not accessible by integration
status: 403
```

## Root Cause

The workflow successfully completed all Terraform steps:
- ✅ Terraform Format Check - SUCCESS
- ✅ Terraform Init - SUCCESS
- ✅ Terraform Validate - SUCCESS
- ✅ Terraform Plan - SUCCESS

However, it failed when trying to post the plan results as a comment to the PR because the default `GITHUB_TOKEN` didn't have sufficient permissions.

## Error Details

```
Error: Unhandled error: HttpError: Resource not accessible by integration
'x-accepted-github-permissions': 'issues=write; pull_requests=write'
```

The error message shows that the workflow needs `pull_requests=write` permission to post comments.

## Solution Applied

Added explicit permissions to the workflow file `.github/workflows/terraform-plan.yml`:

```yaml
permissions:
  contents: read
  pull-requests: write
```

This grants the workflow:
- `contents: read` - Read repository contents (required for checkout)
- `pull-requests: write` - Write comments to pull requests (required for posting plan results)

## Changes Made

**File:** `.github/workflows/terraform-plan.yml`

**Change:** Added `permissions` block after the `on` trigger section.

## Next Steps

1. Commit this fix to the `test-ci-workflow` branch
2. Push to GitHub
3. The workflow will automatically re-run on the PR
4. The workflow should now successfully post the Terraform plan as a comment

## Verification

After pushing, verify:
1. Go to: https://github.com/duongvuong2610/kiro-lab/pull/2
2. Check that the workflow runs successfully (green checkmark)
3. Verify that a comment with the Terraform plan appears on the PR

## Additional Notes

- The Terraform plan itself is working correctly
- All 34 resources will be created as expected
- The infrastructure includes: VPC, ECS Fargate, RDS, S3, ALB, and supporting resources
- No Terraform code changes are needed - this was purely a GitHub Actions permissions issue

## Reference

- GitHub Docs: [Automatic token authentication](https://docs.github.com/en/actions/security-guides/automatic-token-authentication)
- GitHub Docs: [Permissions for the GITHUB_TOKEN](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#permissions-for-the-github_token)
