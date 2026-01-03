#Security Group for ALB (Public)
resource "aws_security_group" "alb" { 
    name = "${var.project_name}-${var.environment}-alb-sg"
    description = "Security group for ALB"
    vpc_id = var.vpc_id 
    ingress { 
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTP from internet"
    }
    ingress { 
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow HTTPS from internet"
    }
    egress { 
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow all outbound"
    }
    tags = merge ( 
        var.tags, { 
            Name = "${var.project_name}-${var.environment}-alb-sg"
        }
    )
}
#Security Group for EC2 Video Processors (private)
resource "aws_security_group" "ec2_processor" { 
    name = "${var.project_name}-${var.environment}-ec2-processor-sg"
    description = "Security group for EC2 video processing instances"
    vpc_id = var.vpc_id 
    ingress { 
        from_port = 80
        to_port = 80
        protocol = "tcp"
        security_groups = [aws_security_group.alb.id]
        description = "Allow HTTP from ALB"
    }
    ingress { 
        from_port = 22
        to_port = 22
        protocol = "tcp"
        cidr_blocks = [var.vpc_cidr]
        description = "Allow SSH from within VPC(debugging)"
    }
    egress { 
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
        description = "Allow all outbound (for S3, SQS - trough VPC endpoints)"
    }
    tags = merge ( 
        var.tags,
        { 
            Name = "${var.project_name}-${var.environment}-ec2-processor-sg"
        }
    )
}
#IAM Role for EC2 Video Processors
resource "aws_iam_role" "ec2_processor" { 
    name = "${var.project_name}-${var.environment}-ec2-processor-role"
    assume_role_policy = jsonencode({ 
        Version = "2012-10-17"
        Statement = [ 
            { 
                Action = "sts:AssumeRole"
                Effect = "Allow"
                Principal = { 
                    Service = "ec2.amazonaws.com"
                }
            }
        ]
    })
    tags = merge ( 
        var.tags, { 
            Name = "${var.project_name}-${var.environment}-ec2-processor-role"
        }
    )
}
# IAM Policy for EC2 to access S3, SQS, CloudWatch
resource "aws_iam_role_policy" "ec2_processor_policy" {
  name = "${var.project_name}-${var.environment}-ec2-processor-policy"
  role = aws_iam_role.ec2_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = concat(
          var.s3_bucket_arns,
          [for arn in var.s3_bucket_arns : "${arn}/*"]
        )
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes",
          "sqs:ChangeMessageVisibility"
        ]
        Resource = var.sqs_queue_arn != "" ? [var.sqs_queue_arn] : []
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

#IAM Instace Profile for EC2
resource "aws_iam_instance_profile" "ec2_processor" { 
    name = "${var.project_name}-${var.environment}-ec2-processor-profile"
    role = aws_iam_role.ec2_processor.name 
    tags = merge ( 
        var.tags, 
        { 
            Name = "${var.project_name}-${var.environment}-ec2-processor-profile"
        }
    )
}
