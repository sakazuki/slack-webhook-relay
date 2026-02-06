output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${oci_apigateway_deployment.webhook_deployment.endpoint}/v1/webhooks"
}

output "function_id" {
  description = "Function OCID"
  value       = oci_functions_function.webhook_relay.id
}

output "function_invoke_endpoint" {
  description = "Function invoke endpoint"
  value       = oci_functions_function.webhook_relay.invoke_endpoint
}

output "gateway_id" {
  description = "API Gateway OCID"
  value       = oci_apigateway_gateway.webhook_gateway.id
}

output "container_repository" {
  description = "Container repository path"
  value       = "${var.oci_region}.ocir.io/${var.tenancy_namespace}/${oci_artifacts_container_repository.webhook_relay_repo.display_name}"
}

output "usage_example" {
  description = "Usage example"
  value       = <<-EOT
    curl -X POST "${oci_apigateway_deployment.webhook_deployment.endpoint}/v1/webhooks?d=https://hooks.slack.com/services/YOUR/WEBHOOK/PATH" \
      -H "Content-Type: application/json" \
      -d '{
        "alert": "High CPU Usage",
        "severity": "warning",
        "host": "web-server-01",
        "value": 85.3
      }'
  EOT
}

output "docker_build_command" {
  description = "Docker build and push commands"
  value       = <<-EOT
    # Build the Docker image
    docker build -t ${var.oci_region}.ocir.io/${var.tenancy_namespace}/${oci_artifacts_container_repository.webhook_relay_repo.display_name}:${var.function_version} .
    
    # Login to OCIR (replace <username> and <auth_token>)
    docker login ${var.oci_region}.ocir.io -u <username> -p <auth_token>
    
    # Push the image
    docker push ${var.oci_region}.ocir.io/${var.tenancy_namespace}/${oci_artifacts_container_repository.webhook_relay_repo.display_name}:${var.function_version}
  EOT
}
