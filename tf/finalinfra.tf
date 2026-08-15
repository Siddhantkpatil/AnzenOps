###############################################################################
# DEVSECOPS AWS INFRASTRUCTURE
#
# COMPLETE ARCHITECTURE
#
# VPC: 10.0.0.0/16
#
# PUBLIC SUBNET
#   ├── Public EC2
#   │    ├── Bastion Host
#   │    ├── Nginx Reverse Proxy
#   │    └── SonarQube
#   │
#   └── NAT Gateway
#
# PRIVATE SUBNET A
#   └── EKS Worker Node 1
#
# PRIVATE SUBNET B
#   ├── EKS Worker Node 2
#   ├── Monitoring EC2
#   │    ├── Prometheus
#   │    ├── Grafana
#   │    └── Wazuh
#   │
#   └── PostgreSQL EC2
#
# AWS MANAGED SERVICES
#   ├── EKS Control Plane
#   └── ECR
#
# ELASTIC IPs
#   ├── EIP #1 -> Public EC2
#   └── EIP #2 -> NAT Gateway
#
###############################################################################


###############################################################################
# 1. TERRAFORM CONFIGURATION
###############################################################################

# terraform {
#   required_version = ">= 1.5.0"

#   required_providers {
#     aws = {
#       source  = "hashicorp/aws"
#       version = "~> 6.0"
#     }
#   }
# }


###############################################################################
# 2. AWS PROVIDER
#
# The AWS provider tells Terraform:
# "Create all resources in AWS."
#
# Change the region if your project uses another AWS region.
###############################################################################

# provider "aws" {
#   region = "ap-south-1"
# }


###############################################################################
# 3. DATA SOURCE - AVAILABILITY ZONES
#
# AWS Region
#     |
#     ├── Availability Zone A
#     └── Availability Zone B
#
# We use two AZs so that our EKS workers are distributed across
# two separate Availability Zones.
###############################################################################

data "aws_availability_zones" "available" {
  state = "available"
}


###############################################################################
# 4. VPC
#
# VPC CIDR:
#
#     10.0.0.0/16
#
# This is our complete private network.
#
# It provides the address space from:
#
#     10.0.0.0
#     to
#     10.0.255.255
#
# Subnets will be created from this larger CIDR range.
###############################################################################

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "devsecops-vpc"
  }
}


###############################################################################
# 5. INTERNET GATEWAY
#
# The Internet Gateway connects the VPC to the public internet.
#
# Important:
#
# Creating an Internet Gateway alone does NOT make a subnet public.
#
# The subnet also needs:
#
#     Route Table
#          |
#          └── 0.0.0.0/0 -> Internet Gateway
#
###############################################################################

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "devsecops-igw"
  }
}


###############################################################################
# 6. PUBLIC SUBNET
#
# CIDR:
#
#     10.0.1.0/24
#
# Availability Zone:
#
#     AZ A
#
# Resources:
#
#     Public EC2
#       ├── Bastion
#       ├── Nginx
#       └── SonarQube
#
#     NAT Gateway
#
# The subnet is public because its route table points to the
# Internet Gateway.
###############################################################################

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.1.0/24"

  availability_zone = data.aws_availability_zones.available.names[0]

  map_public_ip_on_launch = true

  tags = {
    Name = "devsecops-public-subnet"
    Tier = "Public"
  }
}


###############################################################################
# 7. PRIVATE SUBNET A
#
# CIDR:
#
#     10.0.10.0/24
#
# Availability Zone:
#
#     AZ A
#
# Resource:
#
#     EKS Worker Node 1
#
# This subnet does NOT have a direct route to the Internet Gateway.
#
# Internet access, if required, goes through:
#
#     EKS Worker
#          |
#          ▼
#     Private Route Table
#          |
#          ▼
#     NAT Gateway
#          |
#          ▼
#     Internet Gateway
#          |
#          ▼
#     Internet
###############################################################################

resource "aws_subnet" "private_a" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.10.0/24"

  availability_zone = data.aws_availability_zones.available.names[0]

  map_public_ip_on_launch = false

  tags = {
    Name = "devsecops-private-subnet-a"
    Tier = "Private"
  }
}


###############################################################################
# 8. PRIVATE SUBNET B
#
# CIDR:
#
#     10.0.20.0/24
#
# Availability Zone:
#
#     AZ B
#
# Resources:
#
#     EKS Worker Node 2
#     Monitoring EC2
#     PostgreSQL EC2
###############################################################################

resource "aws_subnet" "private_b" {
  vpc_id = aws_vpc.main.id

  cidr_block = "10.0.20.0/24"

  availability_zone = data.aws_availability_zones.available.names[1]

  map_public_ip_on_launch = false

  tags = {
    Name = "devsecops-private-subnet-b"
    Tier = "Private"
  }
}


###############################################################################
# 9. PUBLIC ROUTE TABLE
#
# This route table belongs to the Public Subnet.
#
# Default route:
#
#     0.0.0.0/0
#           |
#           ▼
#     Internet Gateway
#
# This means:
#
# "Traffic going anywhere outside the VPC should go to the Internet Gateway."
###############################################################################

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"

    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "devsecops-public-route-table"
  }
}


###############################################################################
# 10. PUBLIC ROUTE TABLE ASSOCIATION
#
# This connects:
#
#     Public Subnet
#            |
#            ▼
#     Public Route Table
#
###############################################################################

resource "aws_route_table_association" "public" {
  subnet_id = aws_subnet.public.id

  route_table_id = aws_route_table.public.id
}


###############################################################################
# 11. ELASTIC IP - NAT GATEWAY
#
# This Elastic IP belongs ONLY to the NAT Gateway.
#
# It allows private resources to access the internet through NAT.
#
# EIP #1
#     |
#     ▼
# NAT Gateway
###############################################################################

resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "devsecops-nat-eip"
  }
}


###############################################################################
# 12. NAT GATEWAY
#
# NAT Gateway is placed inside the PUBLIC SUBNET.
#
# Why?
#
# Because NAT Gateway itself needs internet connectivity.
#
# Traffic flow:
#
# Private Resource
#       |
#       ▼
# Private Route Table
#       |
#       ▼
# NAT Gateway
#       |
#       ▼
# Elastic IP
#       |
#       ▼
# Internet Gateway
#       |
#       ▼
# Internet
###############################################################################

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public.id

  depends_on = [
    aws_internet_gateway.igw
  ]

  tags = {
    Name = "devsecops-nat-gateway"
  }
}


###############################################################################
# 13. PRIVATE ROUTE TABLE
#
# Both private subnets use this route table.
#
# Default route:
#
#     0.0.0.0/0
#           |
#           ▼
#     NAT Gateway
#
# This provides OUTBOUND internet access to private resources.
###############################################################################

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"

    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "devsecops-private-route-table"
  }
}


###############################################################################
# 14. PRIVATE SUBNET A - ROUTE TABLE ASSOCIATION
###############################################################################

resource "aws_route_table_association" "private_a" {
  subnet_id = aws_subnet.private_a.id

  route_table_id = aws_route_table.private.id
}


###############################################################################
# 15. PRIVATE SUBNET B - ROUTE TABLE ASSOCIATION
###############################################################################

resource "aws_route_table_association" "private_b" {
  subnet_id = aws_subnet.private_b.id

  route_table_id = aws_route_table.private.id
}


###############################################################################
# 16. ELASTIC IP - PUBLIC EC2
#
# This is a DIFFERENT Elastic IP from the NAT Gateway EIP.
#
# EIP #2
#     |
#     ▼
# Public EC2
#
# Public EC2 roles:
#
#     1. Bastion Host
#     2. Nginx Reverse Proxy
#     3. SonarQube
###############################################################################

resource "aws_eip" "public_ec2" {
  domain = "vpc"

  tags = {
    Name = "devsecops-public-ec2-eip"
  }
}


###############################################################################
# 17. SECURITY GROUP - PUBLIC EC2
#
# This EC2 performs:
#
#     Bastion
#     Nginx
#     SonarQube
#
# INBOUND:
#
#     SSH 22
#       -> Only YOUR IP
#
#     HTTP 80
#       -> Internet
#
#     HTTPS 443
#       -> Internet
#
# We intentionally DO NOT expose:
#
#     SonarQube 9000
#
# directly to the internet.
#
# Nginx will reverse proxy to SonarQube.
###############################################################################

resource "aws_security_group" "bastion" {
  name = "devsecops-public-ec2-sg"

  description = "Security group for Bastion, Nginx and SonarQube"

  vpc_id = aws_vpc.main.id


  # ---------------------------------------------------------------------------
  # SSH
  #
  # IMPORTANT:
  # Replace YOUR_PUBLIC_IP with your actual public IP.
  #
  # Example:
  #
  #     49.36.100.25/32
  #
  # /32 means exactly one IP address.
  # ---------------------------------------------------------------------------

  ingress {
    description = "SSH from administrator"

    from_port = 22
    to_port   = 22

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  # ---------------------------------------------------------------------------
  # HTTP
  # Nginx
  # ---------------------------------------------------------------------------

  ingress {
    description = "HTTP for Nginx"

    from_port = 80
    to_port   = 80

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  # ---------------------------------------------------------------------------
  # HTTPS
  # Nginx
  # ---------------------------------------------------------------------------

  ingress {
    description = "HTTPS for Nginx"

    from_port = 443
    to_port   = 443

    protocol = "tcp"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  # ---------------------------------------------------------------------------
  # OUTBOUND
  # ---------------------------------------------------------------------------

  egress {
    description = "Allow outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  tags = {
    Name = "devsecops-public-ec2-sg"
  }
}


###############################################################################
# 18. SECURITY GROUP - EKS
#
# This Security Group is used for EKS networking.
#
# Internal VPC communication is allowed.
###############################################################################

resource "aws_security_group" "eks" {
  name = "devsecops-eks-sg"

  description = "Security group for EKS cluster networking"

  vpc_id = aws_vpc.main.id


  # ---------------------------------------------------------------------------
  # Allow internal VPC communication
  # ---------------------------------------------------------------------------

  ingress {
    description = "Allow VPC internal communication"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "10.0.0.0/16"
    ]
  }


  # ---------------------------------------------------------------------------
  # OUTBOUND
  # ---------------------------------------------------------------------------

  egress {
    description = "Allow outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  tags = {
    Name = "devsecops-eks-sg"
  }
}


###############################################################################
# 19. SECURITY GROUP - MONITORING EC2
#
# Monitoring EC2 runs:
#
#     Prometheus
#     Grafana
#     Wazuh
#
# It is located in PRIVATE SUBNET B.
#
# Access to monitoring services is allowed ONLY from:
#
#     Public EC2 / Nginx
#
# Public users never directly access Monitoring EC2.
###############################################################################

resource "aws_security_group" "monitoring" {
  name = "devsecops-monitoring-sg"

  description = "Security group for Prometheus Grafana and Wazuh"

  vpc_id = aws_vpc.main.id


  # ---------------------------------------------------------------------------
  # SSH
  #
  # Only the Public EC2 / Bastion can SSH into Monitoring EC2.
  # ---------------------------------------------------------------------------

  ingress {
    description = "SSH from Bastion"

    from_port = 22
    to_port   = 22

    protocol = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]
  }


  # ---------------------------------------------------------------------------
  # Grafana
  #
  # Nginx on Public EC2 will reverse proxy to Grafana.
  # ---------------------------------------------------------------------------

  ingress {
    description = "Grafana from Nginx"

    from_port = 3000
    to_port   = 3000

    protocol = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]
  }


  # ---------------------------------------------------------------------------
  # Prometheus
  # ---------------------------------------------------------------------------

  ingress {
    description = "Prometheus from Nginx"

    from_port = 9090
    to_port   = 9090

    protocol = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]
  }


  # ---------------------------------------------------------------------------
  # Wazuh Dashboard
  #
  # Adjust this later depending on your Wazuh architecture.
  # ---------------------------------------------------------------------------

  ingress {
    description = "Wazuh Dashboard from Nginx"

    from_port = 443
    to_port   = 443

    protocol = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]
  }


  # ---------------------------------------------------------------------------
  # OUTBOUND
  # ---------------------------------------------------------------------------

  egress {
    description = "Allow outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  tags = {
    Name = "devsecops-monitoring-sg"
  }
}


###############################################################################
# 20. SECURITY GROUP - POSTGRESQL
#
# PostgreSQL is PRIVATE.
#
# It is located in:
#
#     Private Subnet B
#
# PostgreSQL port:
#
#     TCP 5432
#
# ONLY EKS resources can connect to PostgreSQL.
#
# We do NOT expose PostgreSQL to:
#
#     0.0.0.0/0
#
# We also do NOT expose PostgreSQL directly to the internet.
###############################################################################

resource "aws_security_group" "postgresql" {
  name = "devsecops-postgresql-sg"

  description = "Security group for private PostgreSQL EC2"

  vpc_id = aws_vpc.main.id


  # ---------------------------------------------------------------------------
  # PostgreSQL
  #
  # Only traffic from EKS Security Group is allowed.
  # ---------------------------------------------------------------------------

  ingress {
    description = "PostgreSQL from EKS"

    from_port = 5432
    to_port   = 5432

    protocol = "tcp"

    security_groups = [
      aws_security_group.eks.id
    ]
  }


  # ---------------------------------------------------------------------------
  # SSH
  #
  # PostgreSQL EC2 can only be accessed through the Bastion.
  # ---------------------------------------------------------------------------

  ingress {
    description = "SSH from Bastion"

    from_port = 22
    to_port   = 22

    protocol = "tcp"

    security_groups = [
      aws_security_group.bastion.id
    ]
  }


  # ---------------------------------------------------------------------------
  # OUTBOUND
  # ---------------------------------------------------------------------------

  egress {
    description = "Allow outbound traffic"

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }


  tags = {
    Name = "devsecops-postgresql-sg"
  }
}


###############################################################################
# 21. ECR REPOSITORY
#
# ECR stores Docker images for our application.
#
# Pipeline:
#
#     GitHub
#        |
#        ▼
#     Jenkins
#        |
#        ├── Build
#        ├── Test
#        ├── SonarQube
#        ├── Docker Build
#        └── Docker Push
#                |
#                ▼
#              ECR
#                |
#                ▼
#              EKS
###############################################################################

resource "aws_ecr_repository" "app" {
  name = "devsecops-flask-app"

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "devsecops-flask-app"
  }
}


###############################################################################
# 22. IAM ROLE - EKS CONTROL PLANE
#
# EKS Control Plane assumes this role.
#
# AWS EKS Service
#       |
#       ▼
# EKS Cluster IAM Role
###############################################################################

resource "aws_iam_role" "eks_cluster_role" {
  name = "devsecops-eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "eks.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


###############################################################################
# 23. EKS CLUSTER IAM POLICY
###############################################################################

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role = aws_iam_role.eks_cluster_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}


###############################################################################
# 24. EKS CLUSTER
#
# EKS Control Plane is AWS managed.
#
# Worker Nodes are deployed into:
#
#     Private Subnet A
#     Private Subnet B
###############################################################################

resource "aws_eks_cluster" "main" {
  name = "devsecops-eks"

  role_arn = aws_iam_role.eks_cluster_role.arn


  vpc_config {

    subnet_ids = [
      aws_subnet.private_a.id,
      aws_subnet.private_b.id
    ]

    security_group_ids = [
      aws_security_group.eks.id
    ]


    # EKS API endpoint accessible from internet.
    # In production, restrict this using public_access_cidrs
    # or use private-only endpoint.
    endpoint_public_access = true

    # Allow private communication to EKS API endpoint.
    endpoint_private_access = true
  }


  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]


  tags = {
    Name = "devsecops-eks"
  }
}


###############################################################################
# 25. IAM ROLE - EKS WORKER NODES
#
# EC2 worker nodes assume this IAM role.
###############################################################################

resource "aws_iam_role" "eks_node_role" {
  name = "devsecops-eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "ec2.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


###############################################################################
# 26. EKS WORKER NODE POLICY
###############################################################################

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}


###############################################################################
# 27. EKS CNI POLICY
###############################################################################

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}


###############################################################################
# 28. ECR READ-ONLY POLICY
#
# Allows EKS worker nodes to pull container images from ECR.
###############################################################################

resource "aws_iam_role_policy_attachment" "eks_ecr_policy" {
  role = aws_iam_role.eks_node_role.name

  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}


###############################################################################
# 29. EKS NODE GROUP A
#
# Exactly ONE worker node.
#
# Located ONLY in:
#
#     Private Subnet A
#
# This guarantees one worker in Private Subnet A.
###############################################################################

resource "aws_eks_node_group" "worker_a" {

  cluster_name = aws_eks_cluster.main.name

  node_group_name = "devsecops-worker-a"

  node_role_arn = aws_iam_role.eks_node_role.arn


  subnet_ids = [
    aws_subnet.private_a.id
  ]


  instance_types = [
    "t3.small"
  ]


  scaling_config {
    desired_size = 1

    min_size = 1

    max_size = 1
  }


  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy
  ]


  tags = {
    Name = "eks-worker-private-a"
    AZ   = "A"
  }
}


###############################################################################
# 30. EKS NODE GROUP B
#
# Exactly ONE worker node.
#
# Located ONLY in:
#
#     Private Subnet B
#
# This guarantees one worker in Private Subnet B.
###############################################################################

resource "aws_eks_node_group" "worker_b" {

  cluster_name = aws_eks_cluster.main.name

  node_group_name = "devsecops-worker-b"

  node_role_arn = aws_iam_role.eks_node_role.arn


  subnet_ids = [
    aws_subnet.private_b.id
  ]


  instance_types = [
    "t3.small"
  ]


  scaling_config {
    desired_size = 1

    min_size = 1

    max_size = 1
  }


  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_policy
  ]


  tags = {
    Name = "eks-worker-private-b"
    AZ   = "B"
  }
}


###############################################################################
# 31. PUBLIC EC2
#
# This ONE EC2 performs THREE roles:
#
#     1. Bastion Host
#     2. Nginx Reverse Proxy
#     3. SonarQube
#
# It is placed in the PUBLIC SUBNET.
#
# It receives:
#
#     Public IP automatically
#     Elastic IP separately
#
# IMPORTANT:
#
# We are installing basic packages here.
#
# Full SonarQube installation should be handled using Ansible.
###############################################################################

resource "aws_instance" "public_ec2" {

  ami = "ami-006f82a1d5a27da54"

  instance_type = "m7i-flex.large"

  key_name = "sid"

  subnet_id = aws_subnet.public.id


  vpc_security_group_ids = [
    aws_security_group.bastion.id
  ]


  associate_public_ip_address = true


  user_data = <<-EOF
              #!/bin/bash

              # ------------------------------------------------
              # Update operating system
              # ------------------------------------------------

              dnf update -y


              # ------------------------------------------------
              # Install Nginx
              # ------------------------------------------------

              dnf install -y nginx

              systemctl enable nginx

              systemctl start nginx


              # ------------------------------------------------
              # Install Java
              #
              # SonarQube requires Java.
              # Exact Java version depends on SonarQube version.
              # ------------------------------------------------

              #dnf install -y java-17-amazon-corretto


              # ------------------------------------------------
              # Install basic utilities
              # ------------------------------------------------

              #dnf install -y wget unzip curl


              # ------------------------------------------------
              # SonarQube
              #
              # Full SonarQube installation will be handled
              # using Ansible.
              #
              # SonarQube will eventually listen on:
              #
              #     localhost:9000
              #
              # Nginx will reverse proxy to it.
              # ------------------------------------------------

              EOF


  tags = {
    Name = "devsecops-public-ec2"

    Role = "Bastion-Nginx-SonarQube"
  }
}


###############################################################################
# 32. ASSOCIATE ELASTIC IP WITH PUBLIC EC2
#
# EIP #1
#     |
#     ▼
# Public EC2
#
# Public EC2 roles:
#
#     Bastion
#     Nginx
#     SonarQube
###############################################################################

resource "aws_eip_association" "public_ec2" {

  instance_id = aws_instance.public_ec2.id

  allocation_id = aws_eip.public_ec2.id
}


###############################################################################
# 33. MONITORING EC2
#
# Located in:
#
#     Private Subnet B
#
# Services:
#
#     Prometheus
#     Grafana
#     Wazuh
#
# Full software installation should be handled by Ansible.
###############################################################################

resource "aws_instance" "monitoring" {

  ami = "ami-006f82a1d5a27da54"

  instance_type = "c7i-flex.large"

  key_name = "sid"

  subnet_id = aws_subnet.private_b.id


  vpc_security_group_ids = [
    aws_security_group.monitoring.id
  ]


  associate_public_ip_address = false


  tags = {
    Name = "devsecops-monitoring-server"

    Role = "Prometheus-Grafana-Wazuh"
  }
}


###############################################################################
# 34. POSTGRESQL EC2
#
# PostgreSQL is hosted on a dedicated private EC2.
#
# Location:
#
#     Private Subnet B
#
# Public IP:
#
#     NO
#
# Internet access:
#
#     Through NAT Gateway if required.
#
# Database access:
#
#     Only from EKS Security Group.
#
# PostgreSQL installation will be handled by Ansible.
###############################################################################

resource "aws_instance" "postgresql" {

  ami = "ami-006f82a1d5a27da54"

  instance_type = "t3.micro"

  key_name = "sid"

  subnet_id = aws_subnet.private_b.id


  vpc_security_group_ids = [
    aws_security_group.postgresql.id
  ]


  associate_public_ip_address = false


  tags = {
    Name = "devsecops-postgresql-server"

    Role = "PostgreSQL"
  }
}


###############################################################################
# 35. OUTPUT - VPC ID
###############################################################################

output "vpc_id" {
  value = aws_vpc.main.id
}


###############################################################################
# 36. OUTPUT - PUBLIC SUBNET ID
###############################################################################

output "public_subnet_id" {
  value = aws_subnet.public.id
}


###############################################################################
# 37. OUTPUT - PRIVATE SUBNET A ID
###############################################################################

output "private_subnet_a_id" {
  value = aws_subnet.private_a.id
}


###############################################################################
# 38. OUTPUT - PRIVATE SUBNET B ID
###############################################################################

output "private_subnet_b_id" {
  value = aws_subnet.private_b.id
}


###############################################################################
# 39. OUTPUT - PUBLIC EC2 ELASTIC IP
#
# Use this IP to:
#
#     SSH into Bastion
#     Access Nginx
#     Access reverse-proxied applications
###############################################################################

output "public_ec2_elastic_ip" {
  value = aws_eip.public_ec2.public_ip
}


###############################################################################
# 40. OUTPUT - PUBLIC EC2 PRIVATE IP
###############################################################################

output "public_ec2_private_ip" {
  value = aws_instance.public_ec2.private_ip
}


###############################################################################
# 41. OUTPUT - NAT GATEWAY ELASTIC IP
#
# This is the public IP used by private resources when
# accessing the internet through NAT.
###############################################################################

output "nat_gateway_elastic_ip" {
  value = aws_eip.nat.public_ip
}


###############################################################################
# 42. OUTPUT - MONITORING EC2 PRIVATE IP
###############################################################################

output "monitoring_private_ip" {
  value = aws_instance.monitoring.private_ip
}


###############################################################################
# 43. OUTPUT - POSTGRESQL EC2 PRIVATE IP
###############################################################################

output "postgresql_private_ip" {
  value = aws_instance.postgresql.private_ip
}


###############################################################################
# 44. OUTPUT - EKS CLUSTER NAME
###############################################################################

output "eks_cluster_name" {
  value = aws_eks_cluster.main.name
}


###############################################################################
# 45. OUTPUT - EKS CLUSTER ENDPOINT
###############################################################################

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.main.endpoint
}


###############################################################################
# 46. OUTPUT - ECR REPOSITORY URL
#
# Jenkins will eventually push Docker images to this repository.
###############################################################################

output "ecr_repository_url" {
  value = aws_ecr_repository.app.repository_url
}