variable "project_name" { 
    description = "Project name used for resource naming"
    type = string
}

variable  "environment" { 
    description = "Environment name (dev,staging,prod)"
    type = string 
}
variable "aws_region" { 
    description = "AWS region to deploy resources"
    type = string 
}
variable "availability_zones" { 
    description = "List of AZ's"
    type = list(string)
}
variable "vpc_cidr" { 
    description = "CIDR block for VPC"
    type = string
    default = "10.0.0.0/16"
}
variable "public_subnet_cidrs" { 
    description = "CIDR blocks for public subnets"
    type = list(string)
    default = ["10.0.1.0/24", "10.0.2.0/24"]
}
variable "private_subnet_cidrs" { 
    description = "CIDR blocks for private subnets"
    type = list(string)
    default = ["10.0.11.0/24", "10.0.12.0/24"]
}
variable "instance_type" { 
    description = "EC2 instances ttype for video processors"
    type = string 
    default = "t3a.small"
}
variable "spot_max_price" { 
    description = "Maximum price for spot instances (per hour)"
    type = string 
    default = "0.01"
}
variable "asg_desired_capacity" { 
    description = "Desired number of EC2 instances in ASG"
    type = number 
    default = 0 
}
variable "asg_min_size" { 
    description = "Minimum number of EC2 instances in ASG"
    type = number
    default = 2

}
variable "asg_max_size" { 
    description = "Maximum number of EC2 instances in ASG"
    type = number 
    default = 2
}

variable "tags" { 
    description = "Common tags to apply to all resources"
    type = map(string)
    default = { }
}
variable "allowed_origins" {
  type        = list(string)
  description = "Allowed CORS origins for API Gateway"
}