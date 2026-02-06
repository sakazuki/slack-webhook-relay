variable "oci_region" {
  description = "OCI region"
  type        = string
  default     = "ap-tokyo-1"
}

variable "compartment_id" {
  description = "OCI Compartment OCID"
  type        = string
}

variable "tenancy_namespace" {
  description = "OCI Tenancy namespace for OCIR"
  type        = string
}

variable "application_name" {
  description = "Functions application name"
  type        = string
  default     = "webhook-relay-app"
}

variable "function_name" {
  description = "Function name"
  type        = string
  default     = "webhook-relay"
}

variable "function_version" {
  description = "Function image version tag"
  type        = string
  default     = "latest"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "function_timeout" {
  description = "Function timeout in seconds"
  type        = number
  default     = 30
}

variable "function_memory_mb" {
  description = "Function memory in MB"
  type        = number
  default     = 256
}

variable "subnet_ids" {
  description = "Subnet IDs for Functions application"
  type        = list(string)
}

variable "gateway_subnet_id" {
  description = "Subnet ID for API Gateway"
  type        = string
}

variable "log_retention_days" {
  description = "Log retention period in days"
  type        = number
  default     = 14
}

variable "enable_rate_limiting" {
  description = "Enable API Gateway rate limiting"
  type        = bool
  default     = false
}

variable "rate_limit_rps" {
  description = "Rate limit in requests per second"
  type        = number
  default     = 100
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    Service   = "webhook-relay"
    ManagedBy = "Terraform"
  }
}
