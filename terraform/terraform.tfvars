environment = "dev"
#AWS Region
aws_region = "us-east-1"
#AZ's 
availability_zones = ["us-east-1a", "us-east-1b"]

#Network Configuration
vpc_cidr = "10.0.0.0/16"
public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

# EC2 Configuration
instance_type = "t3a.small"
spot_max_price = "0.01"

#Auto Scaling Configuration
asg_desired_capacity = 0
asg_min_size = 0
asg_max_size = 2

#Common Tags
tags = { 
    Project = "Oort Cloud Video Editor"
    Environment = "Development"
    ManagedBy = "Pablo"
    Owner = "Pablo"
    CostCenter = "Portfolio"
}
allowed_origins = [ 
    "http://localhost:4200"
]