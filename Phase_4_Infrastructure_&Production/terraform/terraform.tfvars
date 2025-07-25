# Terraform Variables for Online Retail Project - Development Environment

# Environment Configuration
environment = "dev"
aws_region  = "us-east-1"
project_name = "online-retail-project"

# Network Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]

# Compute Configuration
instance_type = "t3.medium"
min_size = 1
max_size = 3
desired_capacity = 2

# Pipeline Component Instance Types
kafka_instance_type = "t3.large"      # For real-time streaming
airflow_instance_type = "t3.medium"   # For workflow orchestration  
spark_instance_type = "t3.large"      # For data processing
monitoring_instance_type = "t3.small" # For monitoring stack

# Database Configuration
database_instance_type = "db.t3.micro"

# Feature Flags
enable_monitoring = true
enable_backup = true
backup_retention_days = 7

# Optional: Add your email for notifications
email_notifications = "your-email@example.com"

# Optional: Domain and SSL (leave empty for now)
domain_name = ""
ssl_certificate_arn = "" 