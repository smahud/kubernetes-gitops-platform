# GCP VPC Module
# Creates a production-grade VPC with private subnets

module "vpc" {
  source  = "terraform-google-modules/network/google"
  version = "~> 7.0"

  project_id   = var.project_id
  network_name = "${var.cluster_name}-vpc"
  routing_mode = "GLOBAL"

  auto_create_subnetworks = false

  subnets = [
    {
      subnet_name   = "${var.cluster_name}-private"
      subnet_ip     = var.private_subnet_cidr
      subnet_region = var.region
      subnet_private_access = "true"
      subnet_flow_logs = "true"
    }
  ]

  secondary_ranges = {
    "${var.cluster_name}-private" = [
      {
        range_name    = "pods"
        ip_cidr_range = "10.10.0.0/16"
      },
      {
        range_name    = "services"
        ip_cidr_range = "10.11.0.0/16"
      }
    ]
  }

  firewall_rules = [
    {
      name        = "${var.cluster_name}-allow-internal"
      description = "Allow internal traffic"
      direction   = "INGRESS"
      ranges      = [var.private_subnet_cidr]
      allow = [
        { protocol = "tcp" },
        { protocol = "udp" },
        { protocol = "icmp" }
      ]
    },
    {
      name        = "${var.cluster_name}-allow-health-checks"
      description = "Allow GCP health checks"
      direction   = "INGRESS"
      ranges      = ["130.211.0.0/22", "35.191.0.0/16"]
      allow = [
        { protocol = "tcp" }
      ]
    }
  ]
}