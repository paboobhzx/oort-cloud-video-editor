data "aws_ami" "amaxon_linux_2023" { 
    most_recent = true
    owners = ["amazon"]
    
    filter { 
        name = "name"
        values = ["al2023-ami-*-x86_64"]
    }
    filter { 
        name = "virtualization-type"
        values = ["hvm"]
    }
}

#Launch Template for EC2 Spot Instances
resource "aws_launch_template" "video_processor" { 
    name_prefix = "${var.project_name}-${var.environment}-processor-"
    image_id = data.aws_ami.amaxon_linux_2023.id 
    instance_type = var.instance_type 
    #Spot Instance Configuration
    instance_market_options { 
        market_type = "spot"
        spot_options { 
            max_price = var.spot_max_price 
            spot_instance_type = "persistent"
            instance_interruption_behavior = "terminate"
        }
    }
    #IAM Instance Profile
    iam_instance_profile { 
        name = var.iam_instance_profile_name 
    }
    #Security Groups
    vpc_security_group_ids = [var.security_group_id]
    #User Data Script
    user_data = base64encode(templatefile("${path.module}/user_data.sh", { 
        sqs_queue_url = var.sqs_queue_url
        raw_videos_bucket = var.raw_videos_bucket_name 
        processed_videos_bucket = var.processed_videos_bucket_name 
        aws_region = data.aws_region.current.name 
    }))
    #Monitoring 
    monitoring { 
        enabled = true
    }
    #EBS Optmization
    ebs_optimized = true 
    #Block devide mapping (increase root volume if needed)
    block_device_mappings { 
        device_name = "/dev/xvda"
        ebs { 
            volume_size = 20 #GB
            volume_type = "gp3"
            delete_on_termination = true 
            encrypted = true 
        }
    }
    #Metadata options (IMDSv2 for security)
    metadata_options { 
        http_endpoint = "enabled"
        http_tokens = "required"
        http_put_response_hop_limit = 1
    }
    tag_specifications { 
        resource_type = "instance"
        tags = merge( 
            var.tags, 
            { 
                Name = "${var.project_name}-${var.environment}-video-processor"
            }
        )
    }
    tag_specifications { 
        resource_type = "volume"
        tags = merge( 
            var.tags,
            { 
                Name = "${var.project_name}-${var.environment}-processor-volume"
            }
        )
    }
}
#Auto Scaling Group
resource "aws_autoscaling_group" "video_processors" { 
    name = "${var.project_name}-${var.environment}-processor-asg"
    vpc_zone_identifier = var.private_subnet_ids 
    desired_capacity = var.desired_capacity 
    min_size = var.min_size 
    max_size = var.max_size
    health_check_type = "EC2"
    health_check_grace_period = 300

    #Mixed instances policy (multiple instance types for better spot availability)
    mixed_instances_policy { 
        instances_distribution { 
            on_demand_base_capacity = 0
            on_demand_percentage_above_base_capacity = 0
            spot_allocation_strategy = "lowest-price"
            spot_instance_pools = 3
        }
        launch_template { 
            launch_template_specification { 
                launch_template_id = aws_launch_template.video_processor.id 
                version = "$Latest"
            }

            #multiple instance type options 
            override { 
                instance_type = "t3a.small"
            }
            override { 
                instance_type = "t3.small"
            }
            override { 
                instance_type = "t2.small"
            }
        }
    }
    #Tags
    tag { 
        key = "Name"
        value = "${var.project_name}-${var.environment}-video-processor"
        propagate_at_launch = true 
    }
    tag { 
        key = "Environment"
        value = var.environment 
        propagate_at_launch = true 
    }
    tag { 
        key = "Project"
        value = var.project_name 
        propagate_at_launch = true 
    }
}
#Auto Scaling Policy - Scale up when SQS queue has messages
resource "aws_autoscaling_policy" "scale_up" { 
    name = "${var.project_name}-${var.environment}-scale-up"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.video_processors.name 
}
#Auto Scaling Policy - Scale down when queue is empty
resource "aws_autoscaling_policy" "scale_down" { 
    name = "${var.project_name}-${var.environment}-scale-down"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.video_processors.name 
}
#CloudWatch Alarm - Scale up when queue has messages
resource "aws_cloudwatch_metric_alarm" "sqs_queue_high" { 
    alarm_name = "${var.project_name}-${var.environment}-sqs-high"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 1
    metric_name = "ApproximateNumberOfMessagesVisible"
    namespace = "AWS/SQS"
    period = 60
    statistic = "Average"
    threshold = 0
    alarm_description = "Scale up when messages in queue"
    alarm_actions = [aws_autoscaling_policy.scale_up.arn]
    dimensions = { 
        QueueName = split("/", var.sqs_queue_url)[4]
    }
}
#CloudWatch Alarm - Scale down when queue is empty
resource "aws_cloudwatch_metric_alarm" "sqs_queue_low" { 
    alarm_name = "${var.project_name}-${var.environment}-sqs-low"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = 2
    metric_name = "ApproximateNumberOfMessagesVisible"
    namespace = "AWS/SQS"
    period = 300
    statistic = "Average"
    threshold = 0
    alarm_description = "Scale down when no messages in queue"
    alarm_actions = [aws_autoscaling_policy.scale_down.arn]
    dimensions = { 
        QueueName = split("/", var.sqs_queue_url)[4]
    }
}

#Get Current AWS REgion
data "aws_region" "current" {}