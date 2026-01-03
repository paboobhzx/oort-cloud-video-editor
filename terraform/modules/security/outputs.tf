output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ec2_processor_security_group_id" {
  description = "ID of the EC2 processor security group"
  value       = aws_security_group.ec2_processor.id
}

output "ec2_processor_iam_role_arn" {
  description = "ARN of the EC2 processor IAM role"
  value       = aws_iam_role.ec2_processor.arn
}

output "ec2_processor_instance_profile_name" {
  description = "Name of the EC2 processor instance profile"
  value       = aws_iam_instance_profile.ec2_processor.name
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.id
}

output "cognito_user_pool_arn" {
  description = "ARN of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.arn
}

output "cognito_user_pool_client_id" {
  description = "ID of the Cognito User Pool Client"
  value       = aws_cognito_user_pool_client.main.id
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain"
  value       = aws_cognito_user_pool_domain.main.domain
}

output "cognito_user_pool_endpoint" {
  description = "Endpoint of the Cognito User Pool"
  value       = aws_cognito_user_pool.main.endpoint
}