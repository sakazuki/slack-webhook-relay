variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "function_name" {
  description = "Lambda function name"
  type        = string
  default     = "webhook-relay"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 30
}

variable "lambda_memory_size" {
  description = "Lambda function memory size in MB"
  type        = number
  default     = 256
}

variable "log_retention_days" {
  description = "CloudWatch Logs retention period in days"
  type        = number
  default     = 14
}

variable "api_stage_name" {
  description = "API Gateway stage name"
  type        = string
  default     = "v1"
}

variable "enable_api_key" {
  description = "Enable API key authentication"
  type        = bool
  default     = false
}

variable "api_quota_limit" {
  description = "API Gateway daily quota limit"
  type        = number
  default     = 10000
}

variable "api_rate_limit" {
  description = "API Gateway rate limit (requests per second)"
  type        = number
  default     = 100
}

variable "api_burst_limit" {
  description = "API Gateway burst limit"
  type        = number
  default     = 200
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Service     = "webhook-relay"
    ManagedBy   = "Terraform"
  }
}
