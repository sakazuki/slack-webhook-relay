output "api_endpoint" {
  description = "API Gateway endpoint URL"
  value       = "${aws_api_gateway_stage.webhook_stage.invoke_url}/webhooks"
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.webhook_relay.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.webhook_relay.arn
}

output "api_gateway_id" {
  description = "API Gateway REST API ID"
  value       = aws_api_gateway_rest_api.webhook_api.id
}

output "api_key" {
  description = "API Key (if enabled)"
  value       = var.enable_api_key ? aws_api_gateway_api_key.webhook_key[0].value : "API Key not enabled"
  sensitive   = true
}

output "usage_example" {
  description = "Usage example"
  value       = <<-EOT
    curl -X POST "${aws_api_gateway_stage.webhook_stage.invoke_url}/webhooks?d=https://hooks.slack.com/services/YOUR/WEBHOOK/PATH" \
      -H "Content-Type: application/json" \
      ${var.enable_api_key ? "-H \"x-api-key: <API_KEY>\" \\\n  " : ""}-d '{
        "alert": "High CPU Usage",
        "severity": "warning",
        "host": "web-server-01",
        "value": 85.3
      }'
  EOT
}
