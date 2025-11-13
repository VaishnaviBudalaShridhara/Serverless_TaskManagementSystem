locals {
  app_name     = "task-api"
  stage        = var.stage
  name_prefix  = "${local.app_name}-${local.stage}"
  tags         = merge(var.tags, { App = local.app_name, Stage = local.stage })
  lambda_rt    = "python3.12"
  table_name   = "${local.name_prefix}-tasks"
  statuses     = ["pending", "in_progress", "completed"]
}

# DynamoDB 

resource "aws_dynamodb_table" "tasks" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "task_id"

  attribute {
    name = "task_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }

  tags = local.tags
}


# Lambda packaging

data "archive_file" "create_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/create_task.py"
  output_path = "${path.module}/lambdas/create_task.zip"
}

data "archive_file" "get_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/get_task.py"
  output_path = "${path.module}/lambdas/get_task.zip"
}

data "archive_file" "list_zip" {
  type        = "zip"
  source_file = "${path.module}/lambdas/list_task.py"
  output_path = "${path.module}/lambdas/list_task.zip"
}


# IAM role and policies (least privilege)

data "aws_iam_policy_document" "assume_role_lambda" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Shared execution role for all three functions
resource "aws_iam_role" "lambda_exec" {
  name               = "${local.name_prefix}-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_lambda.json
  tags               = local.tags
}

# Logging policy (only to these log groups) This does not create AWS logs — it creates the policy rules for them.- eliminating delete, modify options.
data "aws_iam_policy_document" "logs" {
  statement {
    sid     = "CWLogs"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.me.account_id}:log-group:/aws/lambda/${local.name_prefix}-*:*"
    ]
  }
}

#It will allow my Lambdas to create log streams and write logs, and it’s fully tagged and managed by Terraform.
resource "aws_iam_policy" "logs" {
  name   = "${local.name_prefix}-logs"
  policy = data.aws_iam_policy_document.logs.json
  tags   = local.tags
}

# Create permissions per lambda to only the table and only needed actions
data "aws_caller_identity" "me" {}

# Create = PutItem
data "aws_iam_policy_document" "ddb_create" {
  statement {
    actions   = ["dynamodb:PutItem"]
    resources = [aws_dynamodb_table.tasks.arn] #This restricts access to only your tasks table.
  }
}
resource "aws_iam_policy" "ddb_create" {
  name   = "${local.name_prefix}-ddb-create"
  policy = data.aws_iam_policy_document.ddb_create.json
  tags   = local.tags
}

# Get = GetItem
data "aws_iam_policy_document" "ddb_get" {
  statement {
    actions   = ["dynamodb:GetItem"]
    resources = [aws_dynamodb_table.tasks.arn]
  }
}
resource "aws_iam_policy" "ddb_get" {
  name   = "${local.name_prefix}-ddb-get"
  policy = data.aws_iam_policy_document.ddb_get.json
  tags   = local.tags
}

# List = Scan (optionally Query)
data "aws_iam_policy_document" "ddb_list" {
  statement {
    actions   = ["dynamodb:Scan"]
    resources = [aws_dynamodb_table.tasks.arn]
  }
}
resource "aws_iam_policy" "ddb_list" {
  name   = "${local.name_prefix}-ddb-list"
  policy = data.aws_iam_policy_document.ddb_list.json
  tags   = local.tags
}

# Attach shared logs policy
resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.logs.arn
}


# CloudWatch Log Groups (explicit + retention)

resource "aws_cloudwatch_log_group" "create_lg" {
  name              = "/aws/lambda/${local.name_prefix}-create"
  retention_in_days = 14
  tags              = local.tags
}
resource "aws_cloudwatch_log_group" "get_lg" {
  name              = "/aws/lambda/${local.name_prefix}-get"
  retention_in_days = 14
  tags              = local.tags
}
resource "aws_cloudwatch_log_group" "list_lg" {
  name              = "/aws/lambda/${local.name_prefix}-list"
  retention_in_days = 14
  tags              = local.tags
}


# Lambda Functions

resource "aws_lambda_function" "create" {
  function_name = "${local.name_prefix}-create"
  role          = aws_iam_role.lambda_exec.arn
  handler       = "create_task.handler"
  runtime       = local.lambda_rt
  filename      = data.archive_file.create_zip.output_path
  source_code_hash = data.archive_file.create_zip.output_base64sha256 #to deply the lambda code

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tasks.name
      STATUSES   = join(",", local.statuses)
    }
  }

  tags = local.tags

  depends_on = [aws_cloudwatch_log_group.create_lg]
}

resource "aws_iam_role_policy_attachment" "create_ddb_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ddb_create.arn
}

resource "aws_lambda_function" "get" {
  function_name    = "${local.name_prefix}-get"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "get_task.handler"
  runtime          = local.lambda_rt
  filename         = data.archive_file.get_zip.output_path
  source_code_hash = data.archive_file.get_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tasks.name
    }
  }

  tags = local.tags

  depends_on = [aws_cloudwatch_log_group.get_lg]
}

resource "aws_iam_role_policy_attachment" "get_ddb_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ddb_get.arn
}

resource "aws_lambda_function" "list" {
  function_name    = "${local.name_prefix}-list"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "list_task.handler"
  runtime          = local.lambda_rt
  filename         = data.archive_file.list_zip.output_path
  source_code_hash = data.archive_file.list_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.tasks.name
    }
  }

  tags = local.tags

  depends_on = [aws_cloudwatch_log_group.list_lg]
}

resource "aws_iam_role_policy_attachment" "list_ddb_attach" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.ddb_list.arn
}


# API Gateway HTTP API (v2)

resource "aws_apigatewayv2_api" "http" {
  name          = "${local.name_prefix}-httpapi"
  protocol_type = "HTTP"
  cors_configuration {
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["*"]
    allow_headers = ["content-type"]
  }
  tags = local.tags
}

# Integrations
resource "aws_apigatewayv2_integration" "create_int" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "get_int" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get.invoke_arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "list_int" {
  api_id                 = aws_apigatewayv2_api.http.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.list.invoke_arn
  payload_format_version = "2.0"
}

# Routes
resource "aws_apigatewayv2_route" "post_tasks" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "POST /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.create_int.id}"
}

resource "aws_apigatewayv2_route" "get_task" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /tasks/{id}"
  target    = "integrations/${aws_apigatewayv2_integration.get_int.id}"
}

resource "aws_apigatewayv2_route" "list_tasks" {
  api_id    = aws_apigatewayv2_api.http.id
  route_key = "GET /tasks"
  target    = "integrations/${aws_apigatewayv2_integration.list_int.id}"
}



# Stage + Access Logs
resource "aws_cloudwatch_log_group" "http_api_logs" {
  name              = "/aws/apigw/${local.name_prefix}-http"
  retention_in_days = 14
  tags              = local.tags
}

resource "aws_apigatewayv2_stage" "http" {
  api_id      = aws_apigatewayv2_api.http.id
  name        = local.stage
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.http_api_logs.arn
    format          = jsonencode({ requestId = "$context.requestId", routeKey = "$context.routeKey", status = "$context.status", integrationError = "$context.integrationErrorMessage" })
  }

  tags = local.tags
}

# Allow API Gateway to invoke Lambdas
resource "aws_lambda_permission" "apigw_create" {
  statement_id  = "AllowAPIGWInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*/tasks"
}

resource "aws_lambda_permission" "apigw_get" {
  statement_id  = "AllowAPIGWInvokeGet"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*/tasks/*"
}

resource "aws_lambda_permission" "apigw_list" {
  statement_id  = "AllowAPIGWInvokeList"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.list.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.http.execution_arn}/*/*/tasks"
}


# Basic Monitoring Alarms

# Lambda error alarms (each function)
resource "aws_cloudwatch_metric_alarm" "create_errors" {
  alarm_name          = "${local.name_prefix}-create-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    FunctionName = aws_lambda_function.create.function_name
  }
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "get_errors" {
  alarm_name          = "${local.name_prefix}-get-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    FunctionName = aws_lambda_function.get.function_name
  }
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

resource "aws_cloudwatch_metric_alarm" "list_errors" {
  alarm_name          = "${local.name_prefix}-list-errors"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    FunctionName = aws_lambda_function.list.function_name
  }
  treat_missing_data = "notBreaching"
  tags               = local.tags
}

# API 5XX alarm
resource "aws_cloudwatch_metric_alarm" "api_5xx" {
  alarm_name          = "${local.name_prefix}-api-5xx"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "5xx"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    ApiName = aws_apigatewayv2_api.http.name
    Stage   = aws_apigatewayv2_stage.http.name
  }
  treat_missing_data = "notBreaching"
  tags               = local.tags
}
