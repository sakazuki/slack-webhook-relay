terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 5.0"
    }
  }
}

provider "oci" {
  region = var.oci_region
}

# 既存のコンパートメントを参照
data "oci_identity_compartment" "target" {
  id = var.compartment_id
}

# Functions Application
resource "oci_functions_application" "webhook_relay_app" {
  compartment_id = var.compartment_id
  display_name   = var.application_name
  subnet_ids     = var.subnet_ids

  config = {
    NODE_ENV = var.environment
  }

  freeform_tags = var.tags
}

# Container Registry用のリポジトリ
resource "oci_artifacts_container_repository" "webhook_relay_repo" {
  compartment_id = var.compartment_id
  display_name   = "${var.function_name}-repo"
  is_public      = false

  freeform_tags = var.tags
}

# Functions Function
resource "oci_functions_function" "webhook_relay" {
  application_id = oci_functions_application.webhook_relay_app.id
  display_name   = var.function_name
  image          = "${var.oci_region}.ocir.io/${var.tenancy_namespace}/${oci_artifacts_container_repository.webhook_relay_repo.display_name}:${var.function_version}"
  memory_in_mbs  = var.function_memory_mb
  timeout_in_seconds = var.function_timeout

  config = {
    NODE_ENV = var.environment
  }

  freeform_tags = var.tags
}

# API Gateway
resource "oci_apigateway_gateway" "webhook_gateway" {
  compartment_id = var.compartment_id
  endpoint_type  = "PUBLIC"
  subnet_id      = var.gateway_subnet_id
  display_name   = "${var.function_name}-gateway"

  freeform_tags = var.tags
}

# API Deployment
resource "oci_apigateway_deployment" "webhook_deployment" {
  compartment_id = var.compartment_id
  gateway_id     = oci_apigateway_gateway.webhook_gateway.id
  path_prefix    = "/v1"
  display_name   = "${var.function_name}-deployment"

  specification {
    request_policies {
      dynamic "rate_limiting" {
        for_each = var.enable_rate_limiting ? [1] : []
        content {
          rate_in_requests_per_second = var.rate_limit_rps
          rate_key                    = "CLIENT_IP"
        }
      }
    }

    routes {
      path    = "/webhooks"
      methods = ["POST"]

      backend {
        type        = "ORACLE_FUNCTIONS_BACKEND"
        function_id = oci_functions_function.webhook_relay.id
      }

      request_policies {
        query_parameter_validations {
          parameters {
            name     = "d"
            required = true
          }
        }
      }

      response_policies {
        header_transformations {
          set_headers {
            items {
              name   = "X-Content-Type-Options"
              values = ["nosniff"]
            }
          }
        }
      }
    }
  }

  freeform_tags = var.tags
}

# Logging - Application Logs
resource "oci_logging_log_group" "webhook_log_group" {
  compartment_id = var.compartment_id
  display_name   = "${var.function_name}-log-group"

  freeform_tags = var.tags
}

resource "oci_logging_log" "function_invoke_logs" {
  display_name = "${var.function_name}-invoke-logs"
  log_group_id = oci_logging_log_group.webhook_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "invoke"
      resource    = oci_functions_application.webhook_relay_app.id
      service     = "functions"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = var.tags
}

# API Gateway Access Logs
resource "oci_logging_log" "gateway_access_logs" {
  display_name = "${var.function_name}-gateway-access-logs"
  log_group_id = oci_logging_log_group.webhook_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "access"
      resource    = oci_apigateway_gateway.webhook_gateway.id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = var.tags
}

# API Gateway Execution Logs
resource "oci_logging_log" "gateway_execution_logs" {
  display_name = "${var.function_name}-gateway-execution-logs"
  log_group_id = oci_logging_log_group.webhook_log_group.id
  log_type     = "SERVICE"

  configuration {
    source {
      category    = "execution"
      resource    = oci_apigateway_gateway.webhook_gateway.id
      service     = "apigateway"
      source_type = "OCISERVICE"
    }

    compartment_id = var.compartment_id
  }

  is_enabled         = true
  retention_duration = var.log_retention_days

  freeform_tags = var.tags
}
