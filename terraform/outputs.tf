output "vpc_id" {
  description = "VPC ID"
  value       = module.networking.vpc_id
}

output "alb_dns_name" {
  description = "ALB DNS name for accessing the application"
  value       = module.load_balancer.alb_dns_name
}

output "raw_videos_bucket_name" {
  description = "S3 bucket name for raw video uploads"
  value       = module.storage.raw_videos_bucket_name
}

output "processed_videos_bucket_name" {
  description = "S3 bucket name for processed videos"
  value       = module.storage.processed_videos_bucket_name
}

output "sqs_queue_url" {
  description = "SQS queue URL for video processing jobs"
  value       = module.storage.video_jobs_queue_url
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID for authentication"
  value       = module.security.cognito_user_pool_id
}

output "cognito_user_pool_client_id" {
  description = "Cognito User Pool Client ID"
  value       = module.security.cognito_user_pool_client_id
}

output "cognito_user_pool_domain" {
  description = "Cognito User Pool Domain"
  value       = module.security.cognito_user_pool_domain
}

output "cloudwatch_dashboard_name" {
  description = "CloudWatch Dashboard name"
  value       = module.monitoring.dashboard_name
}

output "autoscaling_group_name" {
  description = "Auto Scaling Group name"
  value       = module.compute.autoscaling_group_name
}

# Instructions for user
output "next_steps" {
  description = "Next steps after deployment"
  value = <<-EOT
  
  ✅ Infrastructure deployed successfully!
  
  Next steps:
  1. Access your ALB at: http://${module.load_balancer.alb_dns_name}
  2. Upload videos to S3: ${module.storage.raw_videos_bucket_name}
  3. Monitor processing: ${module.monitoring.dashboard_name}
  4. Configure Cognito in your Angular app:
     - User Pool ID: ${module.security.cognito_user_pool_id}
     - Client ID: ${module.security.cognito_user_pool_client_id}
     - Domain: ${module.security.cognito_user_pool_domain}
  
  To test:
  - Upload a video to the raw bucket
  - Check SQS queue for job
  - EC2 will auto-scale and process
  - Download from processed bucket
  
  To destroy: terraform destroy
  EOT
}
output "api_id" {
  description = "HTTP API Gateway ID"
  value       = module.api.api_id
}

output "api_endpoint" {
  description = "HTTP API Gateway invoke URL"
  value       = module.api.api_endpoint
}
output "api_base_url" { 
  description = "Public API base URL"
  value = module.api.api_invoke_url
}