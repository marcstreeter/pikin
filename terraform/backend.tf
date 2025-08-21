# Backend configuration for storing Terraform state in S3
# This will be configured during terraform init with the actual values
# from your .env file

terraform {
  backend "s3" {
    # Backend configuration is set dynamically via:
    # terraform init -backend-config="bucket=YOUR_BUCKET_NAME" -backend-config="region=YOUR_REGION"
  }
}