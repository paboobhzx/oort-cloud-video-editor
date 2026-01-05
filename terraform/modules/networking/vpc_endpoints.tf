#S3 VPC Gateway Endpoints (free, cost saving)
resource "aws_vpc_endpoint" "s3" { 
    vpc_id = aws_vpc.main.id 
    service_name = "com.amazonaws.${var.aws_region}.s3" 
    vpc_endpoint_type = "Gateway"
    route_table_ids = [ 
        aws_route_table.private.id
    ]
    tags = merge( 
        var.tags,
        { 
            Name = "${var.project_name}-${var.environment}-s3-endpooint"
        }
    )
}
#DynamoDB VPC Gateway Endpoint (free, cost saving)
resource "aws_vpc_endpoint" "dynamodb" { 
    vpc_id = aws_vpc.main.id 
    service_name = "com.amazonaws.${var.aws_region}.dynamodb"
    vpc_endpoint_type = "Gateway"
    route_table_ids = [ 
        aws_route_table.private.id 
    ]
    tags = merge( 
        var.tags,
        { 
            Name = "${var.project_name}-${var.environment}-dynamodb-endpoint"
        }
    )
}
resource "aws_security_group" "vpc_endpoints" { 
    name = "${var.project_name}-${var.environment}-vpce-sg"
    description = "Security group for VPC Interface Endpoints"
    vpc_id = aws_vpc.main.id 

    ingress { 
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = [aws_vpc.main.cidr_block]
    }
    egress { 
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = var.tags
}
locals { 
    interface_endpoints = [ 
        "sqs",
        "ssm",
        "ssmmessages",
        "ec2messages",
        "logs"
    ]
}
resource "aws_vpc_endpoint" "interface" { 
    for_each = toset(local.interface_endpoints)

    vpc_id = aws_vpc.main.id 
    service_name = "com.amazonaws.${var.aws_region}.${each.key}"
    vpc_endpoint_type = "Interface"
    subnet_ids = aws_subnet.private[*].id 
    security_group_ids = [aws_security_group.vpc_endpoints.id]
    private_dns_enabled = true
    tags = merge(
        var.tags,
        { 
            Name = "${var.project_name}-${var.environment}-${each.key}-vpce"
        }
    )
}

# #SQS VPC Interface Endpoint (costs $7/month per AZ)(disable due to costs)
# #Use it if you want EC2 to access SQS without traversing the internet
# resource "aws_vpc_endpoint" "sqs" { 
#     vpc_id = aws_vpc-main.id 
#     service_name = ".com.amazonaws.${var.aws_region}.sqs"
#     vpc_endpoint_type = "Interface"
#     subnet_ids = aws_subnet.private[*].id 
#     security_group_ids = [aws_security_group.vpc_endpoints.id]
#     private_dns_enabled = true 
#     tags = merge(
#         var.tags,
#         { 
#             Name = "${var.project_name}-${var.environment}-sqs-endpoint"
#         }
#     )
# }
# #Security Group for VPC Interface Endpoints (if using SQS endpoint)
# resource "aws_security_group" "vpc_endpoints" { 
#     name = "${var.project_name}-${var.environment}-vpc-endpoints-sg"
#     description = "Security group for VPC Interface endpoint"
#     vpc_id = aws_vpc.main.id 

#     ingress { 
#         from_port = 443
#         to_port = 443
#         protocol = "tcp"
#         cidr_blocks = [var.vpc_cidr]
#         description "Allow HTTPS from VPC"
#     }
#     egress { 
#         from_port = 0
#         to_port = 0
#         protocol = "-1"
#         cidr_blocks = ["0.0.0.0/0"]
#         description = "Allow all outbound"
#     }
#     tags = merge( 
#         var.tags, 
#         { 
#             Name = "${var.project_name}-${var.environment}-vpc-endoints-sg"
#         }
#     )
# }