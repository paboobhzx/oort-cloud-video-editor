output "api_endpoint" { 
    description = "API Gateway endpoint URL"
    value = aws_apigatewayv2_stage.main.invoke_url
}

output "api_id" { 
    description = "API Gateway ID"
    value = aws_apigatewayv2_api.main.id 
}
output "api_invoke_url" {
  description = "Base invoke URL for the HTTP API Gateway"
  value       = aws_apigatewayv2_stage.main.invoke_url
}