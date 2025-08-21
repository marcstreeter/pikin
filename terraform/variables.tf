variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
}

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 128
}

variable "cloudwatch_log_retention" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "owner" {
  description = "Owner of the resources (for tagging and cost tracking)"
  type        = string
}

variable "repository" {
  description = "Repository name (for tagging and identification)"
  type        = string
}

variable "lambda_zip_path" {
  description = "Path to the Lambda deployment package zip file"
  type        = string
  default     = null
}
