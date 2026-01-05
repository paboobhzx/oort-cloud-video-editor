variable "project_name" { 
    description = "Project name"
    type = string
}
variable "environment" { 
    description = "Environment name"
    type = string
}
variable "vpc_id" { 
    description = "VPC ID"
    type = string
}
variable "private_subnet_ids" { 
    description = "List of private subnet IDs for EC2 instances"
    type = list(string)
}
variable "security_group_id" { 
    description = "Security group ID for EC2 instances"
    type = string
}
variable "raw_videos_bucket_name" { 
    description = "S3 bucket name for raw videos"
    type = string
}
variable "processed_videos_bucket_name" { 
    description = "S3 bucket name for processed videos"
    type = string 
}
variable "sqs_queue_url" { 
    description = "SQS queue URl for video jobs"
    type = string
}
variable "instance_type" { 
    description = "EC2 instance type"
    type = string 
    default = "t3a.small"
}
variable "spot_max_price" { 
    description = "Maximum price for spot instances (per hour)"
    type = string
    default = "0.01"
}
variable "desired_capacity" { 
    description = "Desired number of EC2 instances"
    type = number
    default = 0 # ← Start with zero instances
}
variable "min_size" { 
    description = "Mininum number of EC2 instances"
    type = number 
    default = 0 # ← Can scale to zero
}
variable "max_size" { 
    description = "Maximum number of EC2 instances"
    type = number 
    default = 2 # ← Max 2 instances for demos
}
variable "tags" { 
    description = "Common tags"
    type = map(string)
    default = { }
}
variable "iam_instance_profile_name" {
  description = "IAM instance profile name for EC2 video processors"
  type        = string
}