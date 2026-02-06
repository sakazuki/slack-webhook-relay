output "function_url" {
  description = "Lambda Function URL endpoint"
  value       = aws_lambda_function_url.webhook_url.function_url
}

output "lambda_function_name" {
  description = "Lambda function name"
  value       = aws_lambda_function.webhook_relay.function_name
}

output "lambda_function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.webhook_relay.arn
}

output "usage_example" {
  description = "Usage example"
  value       = <<-EOT
    curl -X POST "${aws_lambda_function_url.webhook_url.function_url}?d=https://hooks.slack.com/services/YOUR/WEBHOOK/PATH" \
      -H "Content-Type: application/json" \
      -d '{
        "alert": "High CPU Usage",
        "severity": "warning",
        "host": "web-server-01",
        "value": 85.3
      }'
  EOT
}
