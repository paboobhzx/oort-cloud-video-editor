data "aws_caller_identity" "current" {}

# SQS Queue for Video Processing Jobs
resource "aws_sqs_queue" "video_jobs" {
  name                       = "${var.project_name}-${var.environment}-video-jobs"
  delay_seconds              = 0
  max_message_size           = 262144
  message_retention_seconds  = 86400
  receive_wait_time_seconds  = 20
  visibility_timeout_seconds = 1800

  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.video_jobs_dlq.arn
    maxReceiveCount     = 3
  })

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-${var.environment}-video-jobs"
    }
  )
}

# Dead Letter Queue (for failed processing jobs)
resource "aws_sqs_queue" "video_jobs_dlq" { 
    name = "${var.project_name}-${var.environment}-video-jobs-dlq"
    message_retention_seconds = 1209600 #14 days
    receive_wait_time_seconds = 0
    tags = merge( 
        var.tags,
         { 
            Name = "${var.project_name}-${var.environment}-video-jobs-dlq"
            Type = "Dead Letter Queue"
         }
    )
}

# CloudWatch Alarm for DLQ (alert when message fail)
resource "aws_cloudwatch_metric_alarm" "dlq_messages" { 
    alarm_name = "${var.project_name}-${var.environment}-dlq-messages"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 1
    metric_name = "ApproximateNumberOfMessagesVisible"
    namespace = "AWS/SQS"
    period = 300 #5 minutes
    statistic = "Average"
    threshold = 0
    alarm_description = "Alert when messages arrive in DLQ"
    treat_missing_data = "notBreaching"
    dimensions = { 
        QueueName = aws_sqs_queue.video_jobs_dlq.name 
    }
    tags = var.tags
}

# SQS Queue Policy (allow S3 to send messages on upload)
resource "aws_sqs_queue_policy" "video_jobs" {
  queue_url = aws_sqs_queue.video_jobs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowS3ToSendMessage"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.video_jobs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "${aws_s3_bucket.raw_videos.arn}*"  
          }
        }
      }
    ]
  })
}

# S3 Event Notification - Trigger SQS on video upload
resource "aws_s3_bucket_notification" "video_upload" { 
    bucket = aws_s3_bucket.raw_videos.id 
    queue { 
        queue_arn = aws_sqs_queue.video_jobs.arn 
        events = ["s3:ObjectCreated:*"]
        filter_suffix = ".mp4"
    }
    queue { 
        queue_arn = aws_sqs_queue.video_jobs.arn 
        events = ["s3:ObjectCreated:*"]
        filter_suffix = ".avi"
    }
    queue { 
        queue_arn = aws_sqs_queue.video_jobs.arn 
        events = ["s3:ObjectCreated:*"]
        filter_suffix = ".mov"
    }
    queue { 
        queue_arn = aws_sqs_queue.video_jobs.arn 
        events = ["s3:ObjectCreated:*"]
        filter_suffix = ".webm"
    }
    queue { 
        queue_arn = aws_sqs_queue.video_jobs.arn 
        events = ["s3:ObjectCreated:*"]
        filter_suffix = ".mkv"
    }
    depends_on = [aws_sqs_queue_policy.video_jobs]
}