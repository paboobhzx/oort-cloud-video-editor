# API Gateway and Lambda functions for video processor

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

locals {
  function_prefix = "${var.project_name}-${var.environment}"
}

# ============================================
# IAM Role for Lambda Functions
# ============================================

resource "aws_iam_role" "lambda_role" {
  name = "${local.function_prefix}-api-lambda-role"

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
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "${local.function_prefix}-api-lambda-policy"
  role = aws_iam_role.lambda_role.id
  

  policy = jsonencode({
  Version = "2012-10-17"
  Statement = [
    {
      Effect = "Allow"
      Action = [
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface"
      ]
      Resource = "*"
    },
    {
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "arn:aws:logs:*:*:*"
    },
    {
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetObject",
        "s3:HeadObject"
      ]
      Resource = [
        "${var.raw_videos_bucket_arn}/*",
        "${var.processed_video_bucket_arn}/*"
      ]
    },
    {
      Effect = "Allow"
      Action = [
        "sqs:SendMessage"
      ]
      Resource = var.sqs_queue_arn
    }
  ]
})
}

# ============================================
# Lambda: Get Presigned URL for Upload
# ============================================

data "archive_file" "presigned_upload" {
  type        = "zip"
  source_file = "${path.module}/lambdas/presigned_upload.py"
  output_path = "${path.module}/lambdas/presigned_upload.zip"
}

resource "aws_lambda_function" "presigned_upload" {
  filename         = data.archive_file.presigned_upload.output_path
  function_name    = "${local.function_prefix}-presigned-upload"
  role             = aws_iam_role.lambda_role.arn
  handler          = "presigned_upload.handler"
  source_code_hash = data.archive_file.presigned_upload.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  environment {
    variables = {
      RAW_BUCKET = var.raw_videos_bucket_name
      REGION     = data.aws_region.current.name
    }
  }
}

# ============================================
# Lambda: Submit Job to SQS
# ============================================

data "archive_file" "submit_job" {
  type        = "zip"
  source_file = "${path.module}/lambdas/submit_job.py"
  output_path = "${path.module}/lambdas/submit_job.zip"
}

resource "aws_lambda_function" "submit_job" {
  filename         = data.archive_file.submit_job.output_path
  function_name    = "${local.function_prefix}-submit-job"
  role             = aws_iam_role.lambda_role.arn
  handler          = "submit_job.handler"
  source_code_hash = data.archive_file.submit_job.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  environment {
    variables = {
      SQS_QUEUE_URL = var.sqs_queue_url
      REGION        = data.aws_region.current.name
    }
  }
}

# ============================================
# Lambda: Check Job Status
# ============================================

data "archive_file" "check_status" {
  type        = "zip"
  source_file = "${path.module}/lambdas/check_status.py"
  output_path = "${path.module}/lambdas/check_status.zip"
}

resource "aws_lambda_function" "check_status" {
  filename         = data.archive_file.check_status.output_path
  function_name    = "${local.function_prefix}-check-status"
  role             = aws_iam_role.lambda_role.arn
  handler          = "check_status.handler"
  source_code_hash = data.archive_file.check_status.output_base64sha256
  runtime          = "python3.11"
  timeout          = 30
  memory_size = 256

  environment {
    variables = {
      PROCESSED_BUCKET = var.processed_videos_bucket_name
      REGION           = data.aws_region.current.name
    }
  }
  vpc_config { 
    subnet_ids = var.private_subnet_ids 
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# ============================================
# Lambda: Get Presigned URL for Download
# ============================================

data "archive_file" "presigned_download" {
  type        = "zip"
  source_file = "${path.module}/lambdas/presigned_download.py"
  output_path = "${path.module}/lambdas/presigned_download.zip"
}

resource "aws_lambda_function" "presigned_download" {
  filename         = data.archive_file.presigned_download.output_path
  function_name    = "${local.function_prefix}-presigned-download"
  role             = aws_iam_role.lambda_role.arn
  handler          = "presigned_download.handler"
  source_code_hash = data.archive_file.presigned_download.output_base64sha256
  runtime          = "python3.11"
  timeout          = 10

  environment {
    variables = {
      PROCESSED_BUCKET = var.processed_videos_bucket_name
      REGION           = data.aws_region.current.name
    }
  }
  vpc_config { 
    subnet_ids = var.private_subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }
}

# ============================================
# API Gateway HTTP API
# ============================================

resource "aws_apigatewayv2_api" "main" {
  name          = "${local.function_prefix}-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins     = var.allowed_origins
    allow_methods     = ["GET", "POST", "OPTIONS"]
    allow_headers     = ["Content-Type", "Authorization"]
    expose_headers    = ["*"]
    max_age           = 300
    allow_credentials = false
  }
}

resource "aws_apigatewayv2_stage" "main" {
  api_id      = aws_apigatewayv2_api.main.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_logs.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      responseLength = "$context.responseLength"
    })
  }
}

resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/aws/apigateway/${local.function_prefix}-api"
  retention_in_days = 7
}

# ============================================
# API Gateway Integrations
# ============================================

# Presigned Upload
resource "aws_apigatewayv2_integration" "presigned_upload" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presigned_upload.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "presigned_upload" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /upload"
  target    = "integrations/${aws_apigatewayv2_integration.presigned_upload.id}"
}

resource "aws_lambda_permission" "presigned_upload" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_upload.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Submit Job
resource "aws_apigatewayv2_integration" "submit_job" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.submit_job.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "submit_job" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "POST /job"
  target    = "integrations/${aws_apigatewayv2_integration.submit_job.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id 
}

resource "aws_lambda_permission" "submit_job" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.submit_job.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Check Status
resource "aws_apigatewayv2_integration" "check_status" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.check_status.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "check_status" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /status"
  target    = "integrations/${aws_apigatewayv2_integration.check_status.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id 
}

resource "aws_lambda_permission" "check_status" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.check_status.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}

# Presigned Download
resource "aws_apigatewayv2_integration" "presigned_download" {
  api_id                 = aws_apigatewayv2_api.main.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.presigned_download.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "presigned_download" {
  api_id    = aws_apigatewayv2_api.main.id
  route_key = "GET /download"
  target    = "integrations/${aws_apigatewayv2_integration.presigned_download.id}"

  authorization_type = "JWT"
  authorizer_id = aws_apigatewayv2_authorizer.cognito.id 
}

resource "aws_lambda_permission" "presigned_download" {
  statement_id  = "AllowAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presigned_download.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.main.execution_arn}/*/*"
}
#Wiring Cognito JWT Authorizer to API Gateway
resource "aws_apigatewayv2_authorizer" "cognito" { 
  api_id = aws_apigatewayv2_api.main.id 
  name = "${local.function_prefix}-cognito-authorizer"
  authorizer_type = "JWT"

  identity_sources = [ 
    "$request.header.Authorization"
  ]
  jwt_configuration { 
    issuer = var.cognito_issuer_url
    audience = [var.cognito_client_id]
  }
}
#Security group for Lambda
resource "aws_security_group" "lambda" { 
  name = "${local.function_prefix}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id = var.vpc_id
  egress { 
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }
  tags = merge( 
    var.tags,
    { 
      Name = "${local.function_prefix}-lambda-sg"
    }
  )
}