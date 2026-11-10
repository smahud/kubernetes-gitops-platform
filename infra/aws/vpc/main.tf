# AWS VPC Module
# Creates a production-grade VPC with public and private subnets across 3 AZs

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway     = true
  single_nat_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  enable_classiclink     = false
  assign_generated_ipv6_cidr_block = false

  # Tags
  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-vpc"
  })

  public_subnet_tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-public",
    "kubernetes.io/role/elb" = "1"
  })

  private_subnet_tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-private",
    "kubernetes.io/role/internal-elb" = "1"
  })

  # VPC Flow Logs
  vpc_flow_logs = {
    cloudwatch = {
      destination_arn = aws_cloudwatch_log_group.vpc_flow_logs.arn
      traffic_type    = "ALL"
      log_format      = "${version} ${account-id} ${interface-id} ${srcaddr} ${dstaddr} ${srcport} ${dstport} ${protocol} ${packets} ${bytes} ${start} ${end} ${action} ${log-status}"
    }
  }
}

resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/${var.cluster_name}/flowlogs"
  retention_in_days = 30
  tags              = var.common_tags
}