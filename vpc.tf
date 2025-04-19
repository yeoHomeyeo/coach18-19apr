locals {
  project_name          = "chrisy-coach18"
  availability_zone     = "us-east-1" # Example: Updated Availability Zone
  security_group_name   = "${local.project_name}-secgrp"
  vpc_cidr              = "10.0.0.0/16"
  public_subnet_cidrs   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnet_cidrs  = ["10.0.11.0/24", "10.0.12.0/24"]
  public_subnet_names   = ["${local.project_name}-public-subnet-1", "${local.project_name}-public-subnet-2"]
  private_subnet_names  = ["${local.project_name}-private-subnet-1", "${local.project_name}-private-subnet-2"]
  gateway_name          = "${local.project_name}-gateway"
  vpc_name              = "${local.project_name}-vpc"
  public_rt_name        = "${local.project_name}-public-route-table"
  private_rt_name       = "${local.project_name}-private-route-table"
  ecs_app_name            = "file-message-ecs" # A new project name for ECS resources
  ecs_cluster_name        = "${local.ecs_app_name}-cluster"
  s3_bucket_name          = "${local.ecs_app_name}-upload-bucket"
  sqs_queue_name          = "${local.ecs_app_name}-message-queue"
  ecr_repo_upload_name    = "${local.ecs_app_name}-upload-service"
  ecr_repo_message_name   = "${local.ecs_app_name}-message-service"
  public_subnet_tag_prefix  = "public-subnet"
  private_subnet_tag_prefix = "private-subnet"
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr
  tags = {
    Name = local.vpc_name
  }
}

# Internet Gateway for Public Subnets
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = local.gateway_name
  }
}

# Public Subnet 1
resource "aws_subnet" "public_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[0]
  availability_zone = local.availability_zone
  map_public_ip_on_launch = true # Important for public subnets
  tags = {
    Name = local.public_subnet_names[0]
  }
}

# Public Subnet 2
resource "aws_subnet" "public_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.public_subnet_cidrs[1]
  availability_zone = local.availability_zone
  map_public_ip_on_launch = true # Important for public subnets
  tags = {
    Name = local.public_subnet_names[1]
  }
}

# Private Subnet 1
resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[0]
  availability_zone = local.availability_zone
  tags = {
    Name = local.private_subnet_names[0]
  }
}

# Private Subnet 2
resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_subnet_cidrs[1]
  availability_zone = local.availability_zone
  tags = {
    Name = local.private_subnet_names[1]
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = local.public_rt_name
  }
}

# Associate Public Subnet 1 with the Public Route Table
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

# Associate Public Subnet 2 with the Public Route Table
resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Route Table for Private Subnets (Initially no internet access)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = local.private_rt_name
  }
}

# Associate Private Subnet 1 with the Private Route Table
resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

# Associate Private Subnet 2 with the Private Route Table
resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

# Security Group
resource "aws_security_group" "main" {
  name   = local.security_group_name
  vpc_id = aws_vpc.main.id
  tags = {
    Name = local.security_group_name
  }
}

# Ingress Rule: Allow all TCP traffic from any source
resource "aws_security_group_rule" "ingress_tcp_all" {
  type              = "ingress"
  protocol          = "tcp"
  from_port         = 0
  to_port           = 65535
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}

# Egress Rule: Allow all outbound TCP traffic on port 80
resource "aws_security_group_rule" "egress_tcp_port_80" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.main.id
}