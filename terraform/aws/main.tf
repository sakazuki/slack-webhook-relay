terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Lambda関数用のZIPアーカイブを作成
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../src"
  output_path = "${path.module}/webhook-relay.zip"
  excludes    = ["func.js", "package-lock.json", "node_modules"]
}

# Lambda実行ロール
resource "aws_iam_role" "lambda_role" {
  name = "${var.function_name}-role"

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

  tags = var.tags
}

# CloudWatch Logs用のポリシーをアタッチ
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda関数
resource "aws_lambda_function" "webhook_relay" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = var.function_name
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
  runtime         = "nodejs18.x"
  timeout         = var.lambda_timeout
  memory_size     = var.lambda_memory_size

  environment {
    variables = {
      NODE_ENV = var.environment
    }
  }

  tags = var.tags
}

# CloudWatch Logs グループ
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "webhook_api" {
  name        = "${var.function_name}-api"
  description = "API for webhook relay service"

  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = var.tags
}

# API Gateway リソース (/webhooks)
resource "aws_api_gateway_resource" "webhooks" {
  rest_api_id = aws_api_gateway_rest_api.webhook_api.id
  parent_id   = aws_api_gateway_rest_api.webhook_api.root_resource_id
  path_part   = "webhooks"
}

# API Gateway メソッド (POST)
resource "aws_api_gateway_method" "post_webhook" {
  rest_api_id   = aws_api_gateway_rest_api.webhook_api.id
  resource_id   = aws_api_gateway_resource.webhooks.id
  http_method   = "POST"
  authorization = var.enable_api_key ? "API_KEY" : "NONE"

  request_parameters = {
    "method.request.querystring.d" = true
  }
}

# API Gateway インテグレーション
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.webhook_api.id
  resource_id             = aws_api_gateway_resource.webhooks.id
  http_method             = aws_api_gateway_method.post_webhook.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.webhook_relay.invoke_arn
}

# Lambda実行権限
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.webhook_relay.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.webhook_api.execution_arn}/*/*"
}

# API Gateway デプロイメント
resource "aws_api_gateway_deployment" "webhook_deployment" {
  rest_api_id = aws_api_gateway_rest_api.webhook_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.webhooks.id,
      aws_api_gateway_method.post_webhook.id,
      aws_api_gateway_integration.lambda_integration.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.lambda_integration
  ]
}

# API Gateway ステージ
resource "aws_api_gateway_stage" "webhook_stage" {
  deployment_id = aws_api_gateway_deployment.webhook_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.webhook_api.id
  stage_name    = var.api_stage_name

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      caller         = "$context.identity.caller"
      user           = "$context.identity.user"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      resourcePath   = "$context.resourcePath"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
    })
  }

  tags = var.tags
}

# API Gateway ログ用CloudWatch Logs グループ
resource "aws_cloudwatch_log_group" "api_gateway_logs" {
  name              = "/aws/apigateway/${var.function_name}"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

# API Key (オプション)
resource "aws_api_gateway_api_key" "webhook_key" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.function_name}-key"

  tags = var.tags
}

# Usage Plan (オプション)
resource "aws_api_gateway_usage_plan" "webhook_usage_plan" {
  count = var.enable_api_key ? 1 : 0
  name  = "${var.function_name}-usage-plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.webhook_api.id
    stage  = aws_api_gateway_stage.webhook_stage.stage_name
  }

  quota_settings {
    limit  = var.api_quota_limit
    period = "DAY"
  }

  throttle_settings {
    burst_limit = var.api_burst_limit
    rate_limit  = var.api_rate_limit
  }

  tags = var.tags
}

# Usage Plan とAPI Keyの関連付け
resource "aws_api_gateway_usage_plan_key" "webhook_usage_plan_key" {
  count         = var.enable_api_key ? 1 : 0
  key_id        = aws_api_gateway_api_key.webhook_key[0].id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.webhook_usage_plan[0].id
}
