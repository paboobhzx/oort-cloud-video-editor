variable "project_name" { 
    type = string
    description = "Project name"
}
variable "environment" { 
    type = string
    description = "Environment name (dev, prod, etc)"
}
variable "allowed_origins" { 
    description = "Allowed CORS origins for the API"
    type = list(string)
}
variable "raw_videos_bucket_name" { 
    type = string
}
variable "raw_videos_bucket_arn" { 
    type = string 
}
variable "processed_videos_bucket_name" { 
    type = string
}
variable "processed_video_bucket_arn" { 
    type = string 
}
variable "sqs_queue_url" { 
    type = string 
}
variable "sqs_queue_arn" { 
    type = string 
}
variable "cognito_issuer_url" { 
    type = string
    description = "Cognito User Pool issuer URL"
}
variable "cognito_client_id" { 
    type = string
    description = "Cognito App Client ID"
}