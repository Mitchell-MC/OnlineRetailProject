# Main Terraform Configuration for Online Retail Project
# Phase 4: Infrastructure as Code

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    bucket = "online-retail-terraform-state"
    key    = "phase4/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
      Phase       = "4"
    }
  }
}

# VPC and Networking
module "vpc" {
  source = "./modules/vpc"
  
  vpc_cidr             = var.vpc_cidr
  environment          = var.environment
  project_name         = var.project_name
  availability_zones   = var.availability_zones
}

# EC2 Auto Scaling Group for Application Stack
module "ec2_asg" {
  source = "./modules/ec2_asg"
  
  vpc_id               = module.vpc.vpc_id
  subnet_ids           = module.vpc.private_subnet_ids
  environment          = var.environment
  project_name         = var.project_name
  instance_type        = var.instance_type
  min_size             = var.min_size
  max_size             = var.max_size
  desired_capacity     = var.desired_capacity
}

# S3 Buckets for Data Lake
module "s3_buckets" {
  source = "./modules/s3"
  
  environment  = var.environment
  project_name = var.project_name
}

# CloudWatch Logging
module "cloudwatch" {
  source = "./modules/cloudwatch"
  
  environment  = var.environment
  project_name = var.project_name
}

# IAM Roles and Policies
module "iam" {
  source = "./modules/iam"
  
  environment  = var.environment
  project_name = var.project_name
}

# Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnet_ids
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = module.ec2_asg.asg_name
}

output "s3_bucket_names" {
  description = "S3 bucket names"
  value       = module.s3_buckets.bucket_names
} 