
output "http_api_invoke_url" {
  description = "Base invoke URL for the HTTP API"
  value       = "${aws_apigatewayv2_api.http.api_endpoint}/${aws_apigatewayv2_stage.http.name}/tasks"
}

output "dynamodb_table_name" {
  description = "Deployed DynamoDB table name"
  value       = aws_dynamodb_table.tasks.name
}

