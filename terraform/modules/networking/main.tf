#VPC
resource "aws_vpc" "main" { 
	cidr_block = var.vpc_cidr
	enable_dns_hostnames = true
	enable_dns_support = true

	tags = merge ( 
		var.tags,
		{ 
			name = "${var.project_name}-${var.environment}-vpc"
		}
	)
}
#Internet gateway
resource "aws_internet_gateway" "main" { 
	vpc_id = aws_vpc.main.id 
	tags = merge ( 
		var.tags, 
		{ 
			Name = "${var.project_name}-${var.environment}-igw"
		}
	)
}

#Public subnets
	resource "aws_subnet" "public" { 
	count = length(var.public_subnet_cidrs)
	vpc_id = aws_vpc.main.id 
	cidr_block = var.public_subnet_cidrs[count.index]
	availability_zone = var.availability_zones[count.index]
	map_public_ip_on_launch = true
	tags = merge( 
		var.tags, 
		{ 
			Name = "${var.project_name}-${var.environment}-public-subnet-${count.index + 1}"
			type = "Public"
		}
		
	)
}
#Private subnets
resource "aws_subnet" "private" { 
	count = length(var.private_subnet_cidrs)
	vpc_id = aws_vpc.main.id 
	cidr_block = var.private_subnet_cidrs[count.index]
	availability_zone = var.availability_zones[count.index]
	tags = merge ( 
		var.tags, 
		{ 
			Name = "${var.project_name}-${var.environment}-private-subnet-${count.index + 1}"
			Type = "Private"
		}
	)
}
#Public Route Table
resource "aws_route_table" "public" { 
	vpc_id = aws_vpc.main.id 
	route { 
		cidr_block = "0.0.0.0/0"
		gateway_id = aws_internet_gateway.main.id 
	}
	tags = merge( 
		var.tags, 
		{ 
			Mame = "${var.project_name}-${var.environment}-publlic-rt"
		}
	)
}
#Private Route Table
resource "aws_route_table" "private" { 
	vpc_id = aws_vpc.main.id 
	tags = merge ( 
		var.tags, { 
			Name = "${var.project_name}-${var.environment}-private-rt"
		}
	)
}
#Associate public subnets with public route table
resource "aws_route_table_association" "public" { 
	count = length(aws_subnet.public)
	subnet_id = aws_subnet.public[count.index].id 
	route_table_id = aws_route_table.public.id 
}
#Associate private subnets with private route table
resource "aws_route_table_association" "private" { 
	count = length(aws_subnet.private)
	subnet_id = aws_subnet.private[count.index].id 
	route_table_id = aws_route_table.private.id 
}

resource "aws_vpc_endpoint" "ssm" { 
	vpc_id = aws_vpc.main.id 
	service_name = "com.amazonaws.${data.aws_region.current.name}.ssm"
	vpc_endpoint_type = "Interface"
	subnet_ids = aws_subnet.private[*].id
	security_group_ids = [aws_security_group.vpc_endpoints.id]
	#private_dns_enabled = true

	tags = merge ( 
		var.tags,
		{ 
			Name = "${var.project_name}-${var.environment}-ssm-endpoint"
		}
	)
}
# EC2 Messages VPC Endpoint
resource "aws_vpc_endpoint" "ec2messages" { 
	vpc_id = aws_vpc.main.id 
	service_name = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
	vpc_endpoint_type = "Interface"
	subnet_ids = aws_subnet.private[*].id 
	security_group_ids = [aws_security_group.vpc_endpoints.id]
	#private_dns_enabled = true
	tags = merge( 
		var.tags, { 
			Name = "${var.project_name}-${var.environment}-ec2messages-endpoint"
		}
	)
}
#SSM Messages VPC Endpoint (required for ssm)
resource "aws_vpc_endpoint" "ssmmessages" { 
	vpc_id = aws_vpc.main.id 
	service_name = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
	vpc_endpoint_type = "Interface"
	subnet_ids = aws_subnet.private[*].id 
	security_group_ids = [aws_security_group.vpc_endpoints.id]
	#private_dns_enabled = true
	tags = merge(
		var.tags, { 
			Name = "${var.project_name}-${var.environment}-ssmmessages-endpoint"
		}
	)
}
#Security group for VPC Endpoints
resource "aws_security_group" "vpc_endpiints" { 
	name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
	description = "Security group for VPC Interface Endpoints"
	vpc_id = aws_vpc.main.id 
	ingress { 
		from_port = 443
		to_port = 443
		protocol = "tcp"
		cidr_blocks = [var.vpc_cidr]
		description = "Allow HTTPS from VPC"
	}
	egress { 
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
		description = "Allow all outbound"
		
	}
	tags = merge( 
			var.tags, 
			{ 
				Name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
			}
		)
}
data "aws_region" "current" {}