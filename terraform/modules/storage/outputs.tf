output "raw_videos_bucket_name" {
  description = "Name of the raw videos S3 bucket"
  value       = aws_s3_bucket.raw_videos.id
}

output "raw_videos_bucket_arn" {
  description = "ARN of the raw videos S3 bucket"
  value       = aws_s3_bucket.raw_videos.arn
}

output "processed_videos_bucket_name" {
  description = "Name of the processed videos S3 bucket"
  value       = aws_s3_bucket.processed_videos.id
}

output "processed_videos_bucket_arn" {
  description = "ARN of the processed videos S3 bucket"
  value       = aws_s3_bucket.processed_videos.arn
}

output "video_jobs_queue_url" {
  description = "URL of the video jobs SQS queue"
  value       = aws_sqs_queue.video_jobs.url
}

output "video_jobs_queue_arn" {
  description = "ARN of the video jobs SQS queue"
  value       = aws_sqs_queue.video_jobs.arn
}

output "video_jobs_dlq_url" {
  description = "URL of the video jobs Dead Letter Queue"
  value       = aws_sqs_queue.video_jobs_dlq.url
}

output "video_jobs_dlq_arn" {
  description = "ARN of the video jobs Dead Letter Queue"
  value       = aws_sqs_queue.video_jobs_dlq.arn
}

output "s3_bucket_arns" {
  description = "List of all S3 bucket ARNs"
  value = [
    aws_s3_bucket.raw_videos.arn,
    aws_s3_bucket.processed_videos.arn
  ]
}