# Simplified Terraform Configuration for Online Retail Project - Starter
# Phase 4: Infrastructure as Code

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  # Comment out S3 backend for initial setup
  # backend "s3" {
  #   bucket = "online-retail-terraform-state"
  #   key    = "phase4/terraform.tfstate"
  #   region = "us-east-1"
  # }
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

# S3 Bucket for Data Lake (simplified)
resource "aws_s3_bucket" "data_lake" {
  bucket = "${var.project_name}-${var.environment}-data-lake-${random_id.bucket_suffix.hex}"

  tags = {
    Name        = "${var.project_name}-${var.environment}-data-lake"
    Environment = var.environment
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "data_lake_versioning" {
  bucket = aws_s3_bucket.data_lake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Security Group for Pipeline Components
resource "aws_security_group" "pipeline_sg" {
  name        = "${var.project_name}-${var.environment}-pipeline-sg"
  description = "Security group for online retail pipeline components"
  vpc_id      = module.vpc.vpc_id

  # Kafka ports
  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Airflow web server
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # All outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-pipeline-sg"
  }
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

output "data_lake_bucket_name" {
  description = "S3 Data Lake bucket name"
  value       = aws_s3_bucket.data_lake.bucket
}

output "pipeline_security_group_id" {
  description = "Security group ID for pipeline components"
  value       = aws_security_group.pipeline_sg.id
} 