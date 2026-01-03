output "launch_template_id" { 
    description = "ID of the launch template"
    value = aws_launch_template.video_processor.id 
}
output "launch_template_latest_version" { 
    description = "Latest version of the launch template"
    value = "aws_launch_template.video_processor.latest_version"
}
output "autoscaling_group_name" { 
    description = "Name of the Auto Scaling Group"
    value = aws_autoscaling_group.video_processors.name 
}
output "autoscaling_group_arn" { 
    description = "ARN of the Auto Scaling Group"
    value = aws_autoscaling_group.video_processors.arn 
}