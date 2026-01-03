output "vpc_id" { 
    description = "ID of the VPC"
    value = aws_vpc.main.id 
}
output "vpc_cidr" { 
    description = "CIDR block of the VPC"
    value = aws_vpc.main.cidr_block 
}
output "public_subnet_ids" { 
    description = "IDs of public subnets"
    value = aws_subnet.public[*].id 
}
output "private_subnet_ids" { 
    description = "IDS of private subnets"
    value = aws_subnet.private[*].id 
}
output "internet_gateway_id" { 
    description = "ID of the internet gateway"
    value = aws_internet_gateway.main.id 
}
output "public_route_table_id" { 
    description = "ID of the public route table"
    value = aws_route_table.public.id 
}
output "private_route_table_id" { 
    description = "Id of the private route table"
    value = aws_route_table.private.id 
}
output "s3_endpoint_id" { 
    description = "ID of the S3 VPC Endpoint"
    value = aws_vpc_endpoint.s3.id 
}
output "dynamodb_endpoint_id" { 
    description = "ID of the DynamoDB VPC Endpoint"
    value = aws_vpc_endpoint.dynamodb.id 
}
