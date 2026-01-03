#S3 Bucket for raw videos (uploads)
resource "aws_s3_bucket" "raw_videos" { 
    bucket = "${var.project_name}-${var.environment}-raw-videos-${random_string.bucket_suffix.result}"
    tags = merge (
        var.tags, 
        { 
            Name = "${var.project_name}-${var.environment}-raw-videos"
            Type = "Raw videos"
        }
    )
}
#S3 Bucket for processed videos (outputs)
resource "aws_s3_bucket" "processed_videos" { 
    bucket = "${var.project_name}-${var.environment}-processed-videos-${random_string.bucket_suffix.result}"
    tags = merge ( 
        var.tags,
        { 
            Name = "${var.project_name}-${var.environment}-processed-videos"
            Type = "Processed videos"
        }
    )
}
#Random suffix for unique bucket names
resource "random_string" "bucket_suffix" { 
    length = 8
    special = false
    upper = false
}
#Block public access for raw videos bucket
resource "aws_s3_bucket_public_access_block" "raw_videos" { 
    bucket = aws_s3_bucket.raw_videos.id 
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true 
    restrict_public_buckets = true 
}
#Block public access for processed videos bucket
resource "aws_s3_bucket_public_access_block" "processed_videos" { 
    bucket = aws_s3_bucket.processed_videos.id 
    block_public_acls = true
    block_public_policy = true
    ignore_public_acls = true 
    restrict_public_buckets = true 
}
#Lifecycle policy for raw videos (delete after 3 days)
resource "aws_s3_bucket_lifecycle_configuration" "raw_videos" { 
    bucket = aws_s3_bucket.raw_videos.id 
    rule { 
        id = "delete-old-raw-videos"
        status = "Enabled"
        filter {}
        expiration { 
            days = 3
        }
    }
}
#Lifecycle policy for processed videos (delete after 1 day)
resource "aws_s3_bucket_lifecycle_configuration" "processed_videos" { 
    bucket = aws_s3_bucket.processed_videos.id 
    rule { 
        id = "delete-old-processed-videos"
        status = "Enabled"
        filter {}
        expiration { 
            days = 1
        }
    }
}
#Enable versioning for raw videos (optional - helps prevent accidental deletion)
resource "aws_s3_bucket_versioning" "raw_videos" { 
    bucket = aws_s3_bucket.raw_videos.id 
    versioning_configuration { 
        status = "Disabled" #Set to enabled if you want versioning
    }
}
resource "aws_s3_bucket_versioning" "processed_videos" { 
    bucket = aws_s3_bucket.processed_videos.id 
    versioning_configuration { 
        status = "Disabled"
    }
}
#S3 Bucket Policy - Restrict access to VPC Endpoint only (security)
resource "aws_s3_bucket_policy" "raw_videos" { 
    bucket = aws_s3_bucket.raw_videos.id 
    policy = jsonencode({ 
        Version = "2012-10-17"
        Statement = [ 
            { 
                Sid = "AllowVPCEndpointAccess"
                Effect = "Allow"
                Principal = "*"
                Action = [ 
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ]
                Resource = [ 
                    aws_s3_bucket.raw_videos.arn ,
                    "${aws_s3_bucket.raw_videos.arn}/*"
                ]
                Condition = { 
                    StringEquals = { 
                        "aws:SourceVpce" = var.vpc_endpoint_id 
                    }
                }
            }
        ]
    })
}
#S3 Bucket Policy for processed videos
resource "aws_s3_bucket_policy" "processed_videos" { 
    bucket = aws_s3_bucket.processed_videos.id 
    policy = jsonencode({ 
        Version = "2012-10-17",
        Statement = [ 
            { 
                Sid = "AllowVPCEndpointAccess"
                Effect = "Allow"
                Principal = "*"
                Action = [ 
                    "s3:GetObject",
                    "s3:PutObject",
                    "s3:DeleteObject",
                    "s3:ListBucket"
                ]
                Condition = { 
                    StringEquals = { 
                        "aws:SourceVpce" = var.vpc_endpoint_id
                    }
                }
            }
        ]
    })
}
#Enable server-side encryption (best practice, security, needed)
resource "aws_s3_bucket_server_side_encryption_configuration" "raw_videos" { 
    bucket = aws_s3_bucket.raw_videos.id 
    rule { 
        apply_server_side_encryption_by_default { 
            sse_algorithm = "AES256"
        }
    }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "processed_videos" { 
    bucket = aws_s3_bucket.processed_videos.id 
    rule { 
        apply_server_side_encryption_by_default { 
            sse_algorithm = "AES256"
        }
    }
}