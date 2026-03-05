# ECS Cluster
resource "aws_ecs_cluster" "main" {
  name = var.config.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name        = var.config.cluster_name
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.config.environment}-ecs-task-execution-role"

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
    Name        = "${var.config.environment}-ecs-task-execution-role"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Attach AWS managed policy for ECS task execution
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# IAM Policy for Parameter Store access
resource "aws_iam_role_policy" "ecs_task_execution_parameter_store" {
  name = "${var.config.environment}-ecs-parameter-store-access"
  role = aws_iam_role.ecs_task_execution_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:*:*:parameter/${var.config.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = "arn:aws:secretsmanager:*:*:secret:${var.config.environment}/*"
      }
    ]
  })
}

# IAM Role for ECS Task (application permissions)
resource "aws_iam_role" "ecs_task_role" {
  name = "${var.config.environment}-ecs-task-role"

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
    Name        = "${var.config.environment}-ecs-task-role"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# IAM Policy for application-level permissions (example: CloudWatch Logs)
resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "${var.config.environment}-ecs-task-policy"
  role = aws_iam_role.ecs_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:log-group:/ecs/${var.config.environment}/*"
      }
    ]
  })
}

# CloudWatch Log Group for ECS Tasks
resource "aws_cloudwatch_log_group" "ecs_tasks" {
  name              = "/ecs/${var.config.environment}/${var.config.service_name}"
  retention_in_days = 7

  tags = {
    Name        = "${var.config.environment}-ecs-logs"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# ECS Task Definition
resource "aws_ecs_task_definition" "main" {
  family                   = "${var.config.environment}-${var.config.service_name}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.config.task_cpu
  memory                   = var.config.task_memory
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = var.config.service_name
      image     = var.config.container_image
      essential = true

      portMappings = [
        {
          containerPort = var.config.container_port
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs_tasks.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = "ecs"
        }
      }

      secrets = [
        {
          name      = "DB_PASSWORD"
          valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.config.environment}/app/db_password"
        },
        {
          name      = "API_KEY"
          valueFrom = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.config.environment}/app/api_key"
        }
      ]

      environment = [
        {
          name  = "ENVIRONMENT"
          value = var.config.environment
        },
        {
          name  = "SERVICE_NAME"
          value = var.config.service_name
        }
      ]
    }
  ])

  tags = {
    Name        = "${var.config.environment}-${var.config.service_name}-task"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Data sources for dynamic values
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Security Group for ALB
resource "aws_security_group" "alb" {
  name        = "${var.config.environment}-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.config.vpc_id

  ingress {
    description = "Allow HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.config.environment}-alb-sg"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Security Group for ECS Tasks
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.config.environment}-ecs-tasks-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.config.vpc_id

  ingress {
    description     = "Allow traffic from ALB"
    from_port       = var.config.container_port
    to_port         = var.config.container_port
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.config.environment}-ecs-tasks-sg"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.config.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.config.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.config.environment}-alb"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Target Group
resource "aws_lb_target_group" "main" {
  name        = "${var.config.environment}-tg"
  port        = var.config.container_port
  protocol    = "HTTP"
  vpc_id      = var.config.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
  }

  deregistration_delay = 30

  tags = {
    Name        = "${var.config.environment}-tg"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = {
    Name        = "${var.config.environment}-alb-listener"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# ECS Service
resource "aws_ecs_service" "main" {
  name            = var.config.service_name
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = var.config.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.config.private_subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = var.config.service_name
    container_port   = var.config.container_port
  }

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = {
    Name        = "${var.config.environment}-${var.config.service_name}"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_task_execution_role_policy,
    aws_iam_role_policy.ecs_task_execution_parameter_store,
    aws_lb_listener.main
  ]
}

# Auto Scaling Target
resource "aws_appautoscaling_target" "ecs_service" {
  max_capacity       = 10
  min_capacity       = 2
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"

  depends_on = [aws_ecs_service.main]
}

# Auto Scaling Policy - Target Tracking based on CPU
resource "aws_appautoscaling_policy" "ecs_cpu_scaling" {
  name               = "${var.config.environment}-ecs-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_service.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_service.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_service.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 70.0
    scale_in_cooldown  = 300
    scale_out_cooldown = 60
  }
}
