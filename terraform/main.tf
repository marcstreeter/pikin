terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      ManagedBy   = "terraform"
      Environment = "production"
      Owner       = var.owner
      CostCenter  = var.project_name
      Repository  = var.repository
    }
  }
}

# S3 bucket for Lambda function artifacts
resource "aws_s3_bucket" "lambda_artifacts" {
  bucket = "${var.project_name}-lambda-artifacts-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name = "${var.project_name}-lambda-artifacts-${random_id.bucket_suffix.hex}"
  }
}

# Random suffix for bucket name uniqueness
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "lambda_artifacts" {
  bucket = aws_s3_bucket.lambda_artifacts.id
  
  rule {
    id     = "cleanup_old_versions"
    status = "Enabled"
    
    filter {
      prefix = ""
    }
    
    noncurrent_version_expiration {
      noncurrent_days = var.cloudwatch_log_retention
    }
  }
}

# DynamoDB table for application data
resource "aws_dynamodb_table" "app_data" {
  name           = "${var.project_name}-app-data"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"
  
  attribute {
    name = "id"
    type = "S"
  }
  
  tags = {
    Name = "${var.project_name}-app-data"
  }
}

# IAM role for Lambda execution
resource "aws_iam_role" "lambda_execution" {
  name = "${var.project_name}-lambda-execution"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = {
    Name = "${var.project_name}-lambda-execution"
  }
}

# Attach basic Lambda execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for S3 and DynamoDB access
resource "aws_iam_policy" "lambda_custom" {
  name        = "${var.project_name}-lambda-custom"
  description = "Custom permissions for Lambda function to access S3 and DynamoDB"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.lambda_artifacts.arn,
          "${aws_s3_bucket.lambda_artifacts.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = aws_dynamodb_table.app_data.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_custom" {
  role       = aws_iam_role.lambda_execution.name
  policy_arn = aws_iam_policy.lambda_custom.arn
}

# GitHub Actions IAM user for CI/CD deployments
resource "aws_iam_user" "github_actions" {
  name = "${var.project_name}-github-actions"
  
  tags = {
    Name = "${var.project_name}-github-actions"
    Purpose = "CI/CD deployment"
  }
}

# Policy for GitHub Actions to update Lambda functions
resource "aws_iam_policy" "github_actions_lambda" {
  name        = "${var.project_name}-github-actions-lambda"
  description = "Permissions for GitHub Actions to update Lambda functions"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:GetFunction",
          "lambda:UpdateFunctionCode",
          "lambda:UpdateFunctionConfiguration",
          "lambda:GetFunctionConfiguration",
          "lambda:CreateFunction"
        ]
        Resource = aws_lambda_function.main.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:ListFunctions"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the policy to the GitHub Actions user
resource "aws_iam_user_policy_attachment" "github_actions_lambda" {
  user       = aws_iam_user.github_actions.name
  policy_arn = aws_iam_policy.github_actions_lambda.arn
}

# Create access keys for the GitHub Actions user
resource "aws_iam_access_key" "github_actions" {
  user = aws_iam_user.github_actions.name
}

# Create a placeholder Lambda zip if none provided
data "archive_file" "lambda_placeholder" {
  count       = var.lambda_zip_path == null ? 1 : 0
  type        = "zip"
  output_path = "/tmp/lambda_placeholder.zip"
  
  source {
    content  = "package main\n\nimport (\n\t\"github.com/aws/aws-lambda-go/lambda\"\n)\n\nfunc main() {\n\tlambda.Start(func() (string, error) {\n\t\treturn \"Hello from Go Lambda!\", nil\n\t})\n}"
    filename = "main.go"
  }
}

# Lambda function
resource "aws_lambda_function" "main" {
  filename         = var.lambda_zip_path != null ? var.lambda_zip_path : data.archive_file.lambda_placeholder[0].output_path
  function_name    = "${var.project_name}-lambda"
  role            = aws_iam_role.lambda_execution.arn
  handler         = "main"
  runtime         = "provided.al2023"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size
  
  environment {
    variables = {
      PROJECT     = var.project_name
      S3_BUCKET   = aws_s3_bucket.lambda_artifacts.bucket
      DYNAMODB_TABLE = aws_dynamodb_table.app_data.name
    }
  }
  
  tags = {
    Name = "${var.project_name}-lambda"
  }
}

# CloudWatch log group
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${aws_lambda_function.main.function_name}"
  retention_in_days = var.cloudwatch_log_retention
  
  tags = {
    Name = "${var.project_name}-lambda-logs"
  }
}

# Output values
output "lambda_function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.main.function_name
}

output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.main.arn
}

output "lambda_execution_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_execution.arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket for Lambda artifacts"
  value       = aws_s3_bucket.lambda_artifacts.bucket
}

output "dynamodb_table_name" {
  description = "Name of the DynamoDB table"
  value       = aws_dynamodb_table.app_data.name
}

output "aws_region" {
  description = "AWS region used for resources"
  value       = var.aws_region
}

# GitHub Actions credentials
output "github_actions_access_key_id" {
  description = "Access Key ID for GitHub Actions IAM user"
  value       = aws_iam_access_key.github_actions.id
  sensitive   = true
}

output "github_actions_secret_access_key" {
  description = "Secret Access Key for GitHub Actions IAM user"
  value       = aws_iam_access_key.github_actions.secret
  sensitive   = true
}