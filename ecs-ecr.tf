
################################################################################
# ECS Cluster
################################################################################

resource "aws_ecs_cluster" "main" {
  name = local.ecs_cluster_name
  tags = {
    Name = local.ecs_cluster_name
  }
}

################################################################################
# ECR Repositories
################################################################################

resource "aws_ecr_repository" "upload_repo" {
  name                 = local.ecr_repo_upload_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = local.ecr_repo_upload_name
  }
}

resource "aws_ecr_repository" "message_repo" {
  name                 = local.ecr_repo_message_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = local.ecr_repo_message_name
  }
}

################################################################################
# S3 Bucket
################################################################################

resource "aws_s3_bucket" "upload_bucket" {
  bucket = local.s3_bucket_name
  tags = {
    Name = local.s3_bucket_name
  }
}

# Optional: Configure bucket policies, versioning, etc. as needed

################################################################################
# SQS Queue
################################################################################

resource "aws_sqs_queue" "message_queue" {
  name = local.sqs_queue_name
  tags = {
    Name = local.sqs_queue_name
  }
}

# Optional: Configure message retention period, visibility timeout, etc. as needed

################################################################################
# ECS Service Definitions (Fargate)
################################################################################

# Upload Service
resource "aws_ecs_service" "upload_service" {
  name                 = "${local.ecs_app_name}-upload-service"
  cluster              = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.upload_task.arn
  desired_count        = 1
  launch_type          = "FARGATE" #  FARGATE

  network_configuration {
    subnets          = data.aws_subnet_ids.public_subnets.ids # Use public subnets for internet access
    security_groups  = [aws_security_group.main.id]
    assign_public_ip = true #  true for Fargate in public subnets
  }

  # Fargate specific options:
  platform_version = "1.4" # or latest
  #  health_check_grace_period_seconds = 60 # Optional
}

# Message Service
resource "aws_ecs_service" "message_service" {
  name                 = "${local.ecs_app_name}-message-service"
  cluster              = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.message_task.arn
  desired_count        = 1
  launch_type          = "FARGATE" #  FARGATE

  network_configuration {
    subnets          = data.aws_subnet_ids.private_subnets.ids # Use private subnets
    security_groups  = [aws_security_group.main.id]
    assign_public_ip = false
  }

  # Fargate specific options:
  platform_version = "1.4" # or latest
  #  health_check_grace_period_seconds = 60 # Optional
}

################################################################################
# ECS Task Definitions
################################################################################

# Task Definition for the Upload Service
resource "aws_ecs_task_definition" "upload_task" {
  family             = "${local.ecs_app_name}-upload-task"
  network_mode       = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                = 256 # Adjust as needed
  memory             = 512 # Adjust as needed
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.upload_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "upload-container"
      image     = "${aws_ecr_repository.upload_repo.repository_url}:latest" # Or a specific tag
      portMappings = [
        {
          containerPort = 80 # Or the port your application uses
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.ecs_app_name}-upload-service"
          awslogs-region        = local.availability_zone
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

# Task Definition for the Message Service
resource "aws_ecs_task_definition" "message_task" {
  family             = "${local.ecs_app_name}-message-task"
  network_mode       = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                = 256 # Adjust as needed
  memory             = 512 # Adjust as needed
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn      = aws_iam_role.message_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "message-container"
      image     = "${aws_ecr_repository.message_repo.repository_url}:latest" # Or a specific tag
      # No port mappings needed if it's just processing messages
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${local.ecs_app_name}-message-service"
          awslogs-region        = local.availability_zone
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

