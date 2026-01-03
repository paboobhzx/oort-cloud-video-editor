output "dashboard_name" { 
    description = "Name of the CloudWatch Dashboard"
    value = aws_cloudwatch_dashboard.main.dashboard_name 
}
output "log_group_name" { 
    description = "Name of the CloudWatch Log Group"
    value = aws_cloudwatch_log_group.video_processor.name 
}
output "log_group_arn" { 
    description = "ARN of the CloudWatch Log Group"
    value = aws_cloudwatch_log_group.video_processor.arn 
}