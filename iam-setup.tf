################################################################################
# Data Sources to Fetch Subnet IDs
################################################################################

data "aws_subnet_ids" "public_subnets" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${local.project_name}-${local.public_subnet_tag_prefix}-*"
  }
}

data "aws_subnet_ids" "private_subnets" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "${local.project_name}-${local.private_subnet_tag_prefix}-*"
  }
}

################################################################################
# IAM Role for the Upload Service Task
################################################################################

resource "aws_iam_role" "upload_task_role" {
  name = "${local.ecs_app_name}-upload-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # Use ecs-tasks for Fargate
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
  tags = {
    Name = "${local.ecs_app_name}-upload-task-role"
  }
}

resource "aws_iam_policy" "upload_task_policy" {
  name = "${local.ecs_app_name}-upload-task-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "s3:PutObject"
        ],
        Effect = "Allow"
        Resource = "arn:aws:s3:::${local.s3_bucket_name}/*"
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/ecs/${local.ecs_app_name}-upload-service*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "upload_task_role_policy_attach" {
  role       = aws_iam_role.upload_task_role.name
  policy_arn = aws_iam_policy.upload_task_policy.arn
}

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${local.ecs_app_name}-ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
  tags = {
    Name = "${local.ecs_app_name}-ecs-task-execution-role"
  }
}

resource "aws_iam_policy" "ecs_task_execution_role_policy" {
  name = "${local.ecs_app_name}-ecs-task-execution-role-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadManifest",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow"
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy_attach" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_task_execution_role_policy.arn
}

################################################################################
# IAM Role for the Message Service Task
################################################################################

resource "aws_iam_role" "message_task_role" {
  name = "${local.ecs_app_name}-message-task-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "ecs-tasks.amazonaws.com" # Use ecs-tasks
        }
        Effect = "Allow"
        Sid = ""
      },
    ]
  })
  tags = {
    Name = "${local.ecs_app_name}-message-task-role"
  }
}

resource "aws_iam_policy" "message_task_policy" {
  name = "${local.ecs_app_name}-message-task-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage"
        ],
        Effect = "Allow"
        Resource = aws_sqs_queue.message_queue.arn
      },
      {
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Effect = "Allow"
        Resource = "arn:aws:logs:*:*:log-group:/ecs/${local.ecs_app_name}-message-service*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "message_task_role_policy_attach" {
  role       = aws_iam_role.message_task_role.name
  policy_arn = aws_iam_policy.message_task_policy.arn
}
