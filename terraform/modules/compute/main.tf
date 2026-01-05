data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ------------------------------------------------------------
# Launch Template for EC2 Spot Instances
# ------------------------------------------------------------
resource "aws_launch_template" "video_processor" {
  name_prefix   = "${var.project_name}-${var.environment}-processor-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  # IAM Instance Profile 
iam_instance_profile {
  name = var.iam_instance_profile_name
}


  # Security Group
  vpc_security_group_ids = [var.security_group_id]

  # User Data
  #user_data = filebase64("${path.module}/user_data.sh")
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    sqs_queue_url           = var.sqs_queue_url
    raw_videos_bucket       = var.raw_videos_bucket_name
    processed_videos_bucket = var.processed_videos_bucket_name
    aws_region              = data.aws_region.current.name
  }))

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(
    var.tags,
    {
      Name            = "${var.project_name}-${var.environment}-video-processor"
      UserDataVersion = "v2-20260104"
    }
  )

  monitoring {
    enabled = true
  }

  ebs_optimized = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_size           = 30
      volume_type           = "gp3"
      delete_on_termination = true
      encrypted             = true
    }
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
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

# ------------------------------------------------------------
# Auto Scaling Group
# ------------------------------------------------------------
resource "aws_autoscaling_group" "video_processors" {
  name                = "${var.project_name}-${var.environment}-processor-asg"
  vpc_zone_identifier = var.private_subnet_ids

  #desired_capacity = var.desired_capacity
  #min_size         = var.min_size
  #max_size         = var.max_size

  desired_capacity = 1
  min_size         = 1
  max_size         = 1

  health_check_type         = "EC2"
  health_check_grace_period = 300

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "lowest-price"
      spot_instance_pools                      = 3
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.video_processor.id
        version            = "$Latest"
      }

      override { instance_type = "t3a.small" }
      override { instance_type = "t3.small" }
      override { instance_type = "t2.small" }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-video-processor"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }

  tag {
    key                 = "Project"
    value               = var.project_name
    propagate_at_launch = true
  }
}

# ------------------------------------------------------------
# Auto Scaling Policies
# ------------------------------------------------------------
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-${var.environment}-scale-up"
  autoscaling_group_name = aws_autoscaling_group.video_processors.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 60
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-${var.environment}-scale-down"
  autoscaling_group_name = aws_autoscaling_group.video_processors.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}
resource "aws_cloudwatch_metric_alarm" "sqs_queue_high" {
  alarm_name          = "${var.project_name}-${var.environment}-sqs-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 60
  statistic           = "Average"
  threshold           = 0

  alarm_actions = [aws_autoscaling_policy.scale_up.arn]

  treat_missing_data = "notBreaching"

  dimensions = {
    QueueName = split("/", var.sqs_queue_url)[4]
  }
}
resource "aws_cloudwatch_metric_alarm" "sqs_queue_low" {
  alarm_name          = "${var.project_name}-${var.environment}-sqs-low"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods  = 2
  metric_name         = "ApproximateNumberOfMessagesVisible"
  namespace           = "AWS/SQS"
  period              = 300
  statistic           = "Average"
  threshold           = 0

  alarm_actions = [aws_autoscaling_policy.scale_down.arn]

  treat_missing_data = "breaching"

  dimensions = {
    QueueName = split("/", var.sqs_queue_url)[4]
  }
}



# ------------------------------------------------------------
# Region
# ------------------------------------------------------------
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}
