#!/bin/bash

# Bootstrap script for Terraform backend setup
# This script creates the S3 bucket and DynamoDB table required for Terraform state management

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REGION="${AWS_REGION:-us-east-1}"
STATE_BUCKET_PREFIX="terraform-state"
LOCK_TABLE_NAME="terraform-state-lock"
AWS_PROFILE="${AWS_PROFILE:-kiro-lab}"

echo -e "${GREEN}=== Terraform Backend Bootstrap ===${NC}"
echo ""

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    echo "Please install AWS CLI: https://aws.amazon.com/cli/"
    exit 1
fi

# Get AWS Account ID
echo "Using AWS Profile: ${AWS_PROFILE}"
echo "Retrieving AWS Account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --profile ${AWS_PROFILE} --query Account --output text 2>/dev/null)

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Error: Unable to retrieve AWS Account ID${NC}"
    echo "Please ensure AWS CLI is configured with valid credentials"
    exit 1
fi

echo -e "${GREEN}AWS Account ID: ${AWS_ACCOUNT_ID}${NC}"
echo ""

STATE_BUCKET_NAME="${STATE_BUCKET_PREFIX}-${AWS_ACCOUNT_ID}"

# Create S3 bucket for Terraform state
echo "Creating S3 bucket: ${STATE_BUCKET_NAME}..."

if aws s3api head-bucket --bucket "${STATE_BUCKET_NAME}" --profile ${AWS_PROFILE} 2>/dev/null; then
    echo -e "${YELLOW}S3 bucket already exists: ${STATE_BUCKET_NAME}${NC}"
else
    if [ "$REGION" = "us-east-1" ]; then
        aws s3api create-bucket \
            --bucket "${STATE_BUCKET_NAME}" \
            --region "${REGION}" \
            --profile ${AWS_PROFILE}
    else
        aws s3api create-bucket \
            --bucket "${STATE_BUCKET_NAME}" \
            --region "${REGION}" \
            --create-bucket-configuration LocationConstraint="${REGION}" \
            --profile ${AWS_PROFILE}
    fi
    echo -e "${GREEN}✓ S3 bucket created${NC}"
fi

# Enable versioning
echo "Enabling versioning on S3 bucket..."
aws s3api put-bucket-versioning \
    --bucket "${STATE_BUCKET_NAME}" \
    --versioning-configuration Status=Enabled \
    --profile ${AWS_PROFILE}
echo -e "${GREEN}✓ Versioning enabled${NC}"

# Enable encryption
echo "Enabling encryption on S3 bucket..."
aws s3api put-bucket-encryption \
    --bucket "${STATE_BUCKET_NAME}" \
    --server-side-encryption-configuration '{
        "Rules": [{
            "ApplyServerSideEncryptionByDefault": {
                "SSEAlgorithm": "AES256"
            },
            "BucketKeyEnabled": true
        }]
    }' \
    --profile ${AWS_PROFILE}
echo -e "${GREEN}✓ Encryption enabled${NC}"

# Block public access
echo "Blocking public access to S3 bucket..."
aws s3api put-public-access-block \
    --bucket "${STATE_BUCKET_NAME}" \
    --public-access-block-configuration \
        BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true \
    --profile ${AWS_PROFILE}
echo -e "${GREEN}✓ Public access blocked${NC}"

# Add bucket policy for additional security
echo "Adding bucket policy..."
cat > /tmp/bucket-policy.json <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "DenyInsecureTransport",
            "Effect": "Deny",
            "Principal": "*",
            "Action": "s3:*",
            "Resource": [
                "arn:aws:s3:::${STATE_BUCKET_NAME}",
                "arn:aws:s3:::${STATE_BUCKET_NAME}/*"
            ],
            "Condition": {
                "Bool": {
                    "aws:SecureTransport": "false"
                }
            }
        }
    ]
}
EOF

aws s3api put-bucket-policy \
    --bucket "${STATE_BUCKET_NAME}" \
    --policy file:///tmp/bucket-policy.json \
    --profile ${AWS_PROFILE}
rm /tmp/bucket-policy.json
echo -e "${GREEN}✓ Bucket policy applied${NC}"

echo ""

# Create DynamoDB table for state locking
echo "Creating DynamoDB table: ${LOCK_TABLE_NAME}..."

if aws dynamodb describe-table --table-name "${LOCK_TABLE_NAME}" --region "${REGION}" --profile ${AWS_PROFILE} 2>/dev/null > /dev/null; then
    echo -e "${YELLOW}DynamoDB table already exists: ${LOCK_TABLE_NAME}${NC}"
else
    aws dynamodb create-table \
        --table-name "${LOCK_TABLE_NAME}" \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "${REGION}" \
        --tags Key=ManagedBy,Value=Terraform Key=Purpose,Value=StateLocking \
        --profile ${AWS_PROFILE} \
        > /dev/null
    
    echo "Waiting for DynamoDB table to become active..."
    aws dynamodb wait table-exists --table-name "${LOCK_TABLE_NAME}" --region "${REGION}" --profile ${AWS_PROFILE}
    echo -e "${GREEN}✓ DynamoDB table created${NC}"
fi

echo ""
echo -e "${GREEN}=== Backend Setup Complete ===${NC}"
echo ""
echo "Backend Configuration:"
echo "  S3 Bucket:       ${STATE_BUCKET_NAME}"
echo "  DynamoDB Table:  ${LOCK_TABLE_NAME}"
echo "  Region:          ${REGION}"
echo ""
echo "Next Steps:"
echo "1. Update backend.tf files in environments/dev and environments/prod with:"
echo "   bucket = \"${STATE_BUCKET_NAME}\""
echo ""
echo "2. Initialize Terraform in your environment:"
echo "   cd environments/dev"
echo "   terraform init"
echo ""
echo -e "${YELLOW}Note: Keep this S3 bucket and DynamoDB table for as long as you use this infrastructure.${NC}"
echo -e "${YELLOW}Deleting them will result in loss of Terraform state!${NC}"
