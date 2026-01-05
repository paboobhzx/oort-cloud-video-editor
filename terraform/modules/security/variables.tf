variable "project_name" { 
    description = "Project name"
    type = string
}
variable "environment" { 
    description = "Environment name"
    type = string
}
variable "vpc_id" { 
    description = "VPC_ID"
    type = string
}
variable "vpc_cidr" { 
    description = "VPC CIDR Block"
    type = string 
}

variable "s3_bucket_arns" { 
    description = "List of S3 bucjket ARNs for IAM Policies"
    type = list(string)
    default = []
}
variable "sqs_queue_arn" { 
    description = "SQS queue ARN for IAM policies"
    type = string 
    default = ""
}
variable "tags" { 
    description = "Common tags"
    type = map(string)
    default = { }
}