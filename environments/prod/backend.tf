terraform {
  backend "s3" {
    # Replace YOUR_ACCOUNT_ID with your AWS account ID
    # Run scripts/bootstrap-backend.sh to create the backend resources
    bucket         = "terraform-state-471112857175"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
    profile        = "kiro-lab"
  }
}
