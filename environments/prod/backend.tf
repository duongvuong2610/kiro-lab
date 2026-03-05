terraform {
  backend "s3" {
    # Backend configuration for Terraform state
    # For local development: export AWS_PROFILE=kiro-lab
    # For CI/CD: AWS credentials from GitHub Secrets
    bucket         = "terraform-state-471112857175"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
