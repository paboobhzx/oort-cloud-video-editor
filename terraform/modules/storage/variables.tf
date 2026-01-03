variable "project_name" { 
    description = "Project name"
    type = string
}
variable "environment" { 
    description = "Environment name"
    type = string 
}
variable "vpc_endpoint_id" { 
    description = "S3 VPC Endpoint ID for bucket policy"
    type = string
}
variable "tags" { 
    description = "Common tags"
    type = map(string)
    default = { }
}