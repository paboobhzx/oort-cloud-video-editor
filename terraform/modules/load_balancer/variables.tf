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
variable "public_subnet_ids" { 
    description = "List of public subnet IDs for ALB"
    type = list(string)
}
variable "security_group_id" { 
    description = "Security group ID for ALB"
    type = string 
}
variable "tags" { 
    description = "Common tags"
    type = map(string)
    default = {}
}