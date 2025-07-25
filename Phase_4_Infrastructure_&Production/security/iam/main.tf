# IAM Configuration for Online Retail Project Phase 4
# Security and Access Management

# EKS Cluster Role
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.project_name}-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-cluster-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

# EKS Node Group Role
resource "aws_iam_role" "eks_node_group_role" {
  name = "${var.project_name}-eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-eks-node-group-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group_role.name
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group_role.name
}

# Application Service Role
resource "aws_iam_role" "application_service_role" {
  name = "${var.project_name}-application-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-application-service-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Custom policy for application services
resource "aws_iam_policy" "application_service_policy" {
  name        = "${var.project_name}-application-service-policy"
  description = "Policy for application services to access AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-data-lake-${var.environment}",
          "arn:aws:s3:::${var.project_name}-data-lake-${var.environment}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = [
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-user-segments-${var.environment}",
          "arn:aws:dynamodb:${var.aws_region}:*:table/${var.project_name}-recommendations-${var.environment}"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "s3.${var.aws_region}.amazonaws.com"
          }
        }
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "application_service_policy_attachment" {
  role       = aws_iam_role.application_service_role.name
  policy_arn = aws_iam_policy.application_service_policy.arn
}

# Monitoring Service Role
resource "aws_iam_role" "monitoring_service_role" {
  name = "${var.project_name}-monitoring-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-monitoring-service-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Custom policy for monitoring services
resource "aws_iam_policy" "monitoring_service_policy" {
  name        = "${var.project_name}-monitoring-service-policy"
  description = "Policy for monitoring services to access AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeVolumes",
          "ec2:DescribeSecurityGroups"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "monitoring_service_policy_attachment" {
  role       = aws_iam_role.monitoring_service_role.name
  policy_arn = aws_iam_policy.monitoring_service_policy.arn
}

# CI/CD Pipeline Role
resource "aws_iam_role" "cicd_pipeline_role" {
  name = "${var.project_name}-cicd-pipeline-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-cicd-pipeline-role"
    Environment = var.environment
    Project     = var.project_name
  }
}

# Custom policy for CI/CD pipeline
resource "aws_iam_policy" "cicd_pipeline_policy" {
  name        = "${var.project_name}-cicd-pipeline-policy"
  description = "Policy for CI/CD pipeline to deploy infrastructure and applications"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:UpdateClusterConfig",
          "eks:UpdateClusterVersion"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-terraform-state/*",
          "arn:aws:s3:::${var.project_name}-artifacts-${var.environment}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cicd_pipeline_policy_attachment" {
  role       = aws_iam_role.cicd_pipeline_role.name
  policy_arn = aws_iam_policy.cicd_pipeline_policy.arn
}

# Outputs
output "eks_cluster_role_arn" {
  description = "ARN of EKS cluster role"
  value       = aws_iam_role.eks_cluster_role.arn
}

output "eks_node_group_role_arn" {
  description = "ARN of EKS node group role"
  value       = aws_iam_role.eks_node_group_role.arn
}

output "application_service_role_arn" {
  description = "ARN of application service role"
  value       = aws_iam_role.application_service_role.arn
}

output "monitoring_service_role_arn" {
  description = "ARN of monitoring service role"
  value       = aws_iam_role.monitoring_service_role.arn
}

output "cicd_pipeline_role_arn" {
  description = "ARN of CI/CD pipeline role"
  value       = aws_iam_role.cicd_pipeline_role.arn
} 