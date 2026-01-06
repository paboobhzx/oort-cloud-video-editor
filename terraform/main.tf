terraform { 
    required_version = ">= 1.0"
    required_providers { 
        aws = { 
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
        random = { 
            source = "hashicorp/random"
            version = "~> 3.0"
        }
    }
}

provider "aws" { 
    region = var.aws_region 
    default_tags { 
        tags = var.tags
    }
}

#Networking Module
module "networking" { 
    source = "./modules/networking"
    project_name = var.project_name 
    environment = var.environment 
    aws_region = var.aws_region 
    vpc_cidr = var.vpc_cidr
    availability_zones = var.availability_zones
    public_subnet_cidrs = var.public_subnet_cidrs
    private_subnet_cidrs = var.private_subnet_cidrs
    tags = var.tags 
}
#Storage Module
module "storage" { 
    source = "./modules/storage"
    project_name = var.project_name
    environment = var.environment
    vpc_endpoint_id = module.networking.s3_endpoint_id 
    tags = var.tags 
}
#Security module
module "security" { 
    source = "./modules/security"
    project_name = var.project_name 
    environment = var.environment
    aws_region = var.aws_region 

    vpc_id = module.networking.vpc_id
    vpc_cidr = module.networking.vpc_cidr

    s3_bucket_arns = module.storage.s3_bucket_arns 
    sqs_queue_arn = module.storage.video_jobs_queue_arn 

    processed_video_bucket_arn  = module.storage.processed_videos_bucket_arn

    tags = var.tags 
}
#Load balancer  module
module "load_balancer" { 
    source = "./modules/load_balancer"
    project_name = var.project_name 
    environment = var.environment
    vpc_id = module.networking.vpc_id 
    public_subnet_ids = module.networking.public_subnet_ids
    security_group_id = module.security.alb_security_group_id 
    tags = var.tags 
}
#Compute Module
module "compute" {
  source = "./modules/compute"

  project_name = var.project_name
  environment  = var.environment

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  security_group_id  = module.security.ec2_processor_security_group_id

  iam_instance_profile_name = module.security.ec2_processor_instance_profile_name

  raw_videos_bucket_name       = module.storage.raw_videos_bucket_name
  processed_videos_bucket_name = module.storage.processed_videos_bucket_name
  sqs_queue_url                = module.storage.video_jobs_queue_url
}

#Monitoring module
module "monitoring" { 
    source = "./modules/monitoring"
    autoscaling_group_name = module.compute.autoscaling_group_name
    project_name = var.project_name 
    environment = var.environment
    alb_arn_suffix = split("/", module.load_balancer.alb_arn)[1]
    target_group_arn_suffix = split(":", module.load_balancer.target_group_arn)[5]
    sqs_queue_name = split("/", module.storage.video_jobs_queue_url)[4]
    tags = var.tags 
}
#Api Module (HTTP API + Lambdas)
module "api" { 
    source = "./modules/api"
    project_name = var.project_name
    environment = var.environment
    allowed_origins = var.allowed_origins

    #Storage
    raw_videos_bucket_name = module.storage.raw_videos_bucket_name
    raw_videos_bucket_arn = module.storage.raw_videos_bucket_arn
    processed_videos_bucket_name = module.storage.processed_videos_bucket_name
    processed_video_bucket_arn = module.storage.processed_videos_bucket_arn

    #Queue
    sqs_queue_url = module.storage.video_jobs_queue_url
    sqs_queue_arn = module.storage.video_jobs_queue_arn 

    #Cognito (JWT Authorizer)
    cognito_issuer_url = module.security.cognito_user_pool_issuer_url 
    cognito_client_id = module.security.cognito_user_pool_client_id 

  
}