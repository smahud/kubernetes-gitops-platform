# AWS EKS Module
# Creates a production-grade EKS cluster with managed node groups

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 19.0"

  cluster_name    = var.cluster_name
  cluster_version = var.kubernetes_version

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  cluster_endpoint_private_access = true
  cluster_endpoint_public_access_cidrs = ["0.0.0.0/0"]

  # Enable control plane logging
  cluster_log_retention_period = 30

  cluster_encryption_config = [{
    provider_key_arn = aws_kms_key.eks.arn
    resources        = ["secrets"]
  }]

  # Add-ons
  enable_irsa = true

  # EKS managed add-ons
  eks_managed_addons = {
    vpc-cni = {
      most_recent = true
    }
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  # Managed node groups
  eks_managed_node_groups = {
    general = {
      name           = "general"
      instance_types = var.general_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = var.general_min_size
      max_size     = var.general_max_size
      desired_size = var.general_desired_size

      labels = {
        workload-type = "general"
      }

      taints = []

      tags = merge(var.common_tags, {
        Name = "${var.cluster_name}-general"
      })
    }

    gpu = {
      name           = "gpu"
      instance_types = var.gpu_instance_types
      capacity_type  = "SPOT"

      min_size     = var.gpu_min_size
      max_size     = var.gpu_max_size
      desired_size = var.gpu_desired_size

      labels = {
        workload-type = "gpu"
        accelerator   = "nvidia-gpu"
      }

      taints = [{
        key    = "nvidia.com/gpu"
        value  = "true"
        effect = "NO_SCHEDULE"
      }]

      tags = merge(var.common_tags, {
        Name = "${var.cluster_name}-gpu"
      })
    }
  }

  # Fargate profile for system workloads
  eks_fargate_profiles = {
    system = {
      name = "system"
      selectors = [
        {
          namespace = "kube-system"
        },
        {
          namespace = "monitoring"
        }
      ]
    }
  }

  tags = var.common_tags
}

# KMS key for EKS encryption
resource "aws_kms_key" "eks" {
  description             = "EKS encryption key for ${var.cluster_name}"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSService"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey"
        ]
        Resource = "*"
      },
      {
        Sid    = "AllowAdmin"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = "kms:*"
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

data "aws_caller_identity" "current" {}