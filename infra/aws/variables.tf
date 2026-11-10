# Variables for AWS infrastructure

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "production"
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS"
  type        = string
  default     = "1.28"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability zones"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
}

variable "general_instance_types" {
  description = "Instance types for general workloads"
  type        = list(string)
  default     = ["m6i.xlarge"]
}

variable "general_min_size" {
  description = "Minimum size for general node group"
  type        = number
  default     = 3
}

variable "general_max_size" {
  description = "Maximum size for general node group"
  type        = number
  default     = 20
}

variable "general_desired_size" {
  description = "Desired size for general node group"
  type        = number
  default     = 5
}

variable "gpu_instance_types" {
  description = "Instance types for GPU workloads"
  type        = list(string)
  default     = ["g5.2xlarge"]
}

variable "gpu_min_size" {
  description = "Minimum size for GPU node group"
  type        = number
  default     = 0
}

variable "gpu_max_size" {
  description = "Maximum size for GPU node group"
  type        = number
  default     = 10
}

variable "gpu_desired_size" {
  description = "Desired size for GPU node group"
  type        = number
  default     = 0
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Environment = "production"
    Project     = "kubernetes-gitops-platform"
    ManagedBy   = "terraform"
    Owner       = "smahud"
  }
}