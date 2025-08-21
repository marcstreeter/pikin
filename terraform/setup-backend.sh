#!/bin/bash

# Script to set up the S3 backend bucket for Terraform state
# This should be run once before using Terraform
# Variables are passed as command line arguments from the justfile

set -e

# Check if required arguments are provided
if [ $# -ne 3 ]; then
    echo "❌ Usage: $0 <PROJECT_NAME> <AWS_REGION> <TERRAFORM_STATE_BUCKET>"
    echo "   Example: $0 myproject us-west-2 myproject-terraform-state"
    exit 1
fi

# Set variables from command line arguments
PROJECT_NAME="$1"
AWS_REGION="$2"
TERRAFORM_STATE_BUCKET="$3"

echo "🚀 Setting up Terraform S3 backend bucket..."

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "❌ AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if AWS credentials are configured
if ! aws sts get-caller-identity &> /dev/null; then
    echo "❌ AWS credentials not configured. Please run 'aws configure' first."
    exit 1
fi

echo "✅ AWS CLI configured"
echo "📋 Using configuration:"
echo "  Project: $PROJECT_NAME"
echo "  Region: $AWS_REGION"
echo "  State Bucket: $TERRAFORM_STATE_BUCKET"

# Create S3 bucket if it doesn't exist
if aws s3 ls "s3://$TERRAFORM_STATE_BUCKET" 2>&1 | grep -q 'NoSuchBucket'; then
    echo "📦 Creating S3 bucket: $TERRAFORM_STATE_BUCKET"
    aws s3 mb "s3://$TERRAFORM_STATE_BUCKET" --region "$AWS_REGION"
else
    echo "✅ S3 bucket already exists: $TERRAFORM_STATE_BUCKET"
fi

# Enable versioning
echo "🔄 Enabling S3 bucket versioning..."
aws s3api put-bucket-versioning \
    --bucket "$TERRAFORM_STATE_BUCKET" \
    --versioning-configuration Status=Enabled

# Enable encryption
echo "🔒 Enabling S3 bucket encryption..."
aws s3api put-bucket-encryption \
    --bucket "$TERRAFORM_STATE_BUCKET" \
    --server-side-encryption-configuration '{
        "Rules": [
            {
                "ApplyServerSideEncryptionByDefault": {
                    "SSEAlgorithm": "AES256"
                }
            }
        ]
    }'

# Set bucket policy for Terraform state locking (optional)
echo "🔐 Setting bucket policy for Terraform state..."
aws s3api put-bucket-policy \
    --bucket "$TERRAFORM_STATE_BUCKET" \
    --policy '{
        "Version": "2012-10-17",
        "Statement": [
            {
                "Sid": "TerraformStateLock",
                "Effect": "Deny",
                "Principal": "*",
                "Action": "s3:DeleteBucket",
                "Resource": "arn:aws:s3:::'$TERRAFORM_STATE_BUCKET'",
                "Condition": {
                    "StringLike": {
                        "aws:PrincipalArn": "*"
                    }
                }
            }
        ]
    }'

echo "✅ S3 backend bucket setup complete!"