variable "project_name" { 
    description = "Project name"
    type = string
}

variable "environment" { 
    description = "Environment name"
    type = string
}
variable "alb_arn_suffix" { 
    description =  "ARN suffix of the ALB for CloudWatch metrics"
    type = string
}
variable "target_group_arn_suffix" { 
    description = "ARN suffix of the target group for Cloudwatch metrics"
    type = string
}
variable "sqs_queue_name" { 
    description = "Name of the SQS queue for monitoring"
    type = string
}
variable "autoscaling_group_name" { 
    description = "Name of the auto scaling group"
    type = string
}
variable "tags" { 
    description = "Common tags"
    type = map(string)
    default = { }
}