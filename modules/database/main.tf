# DB Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.config.identifier}-subnet-group"
  subnet_ids = var.config.private_subnet_ids

  tags = {
    Name        = "${var.config.identifier}-subnet-group"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name        = "${var.config.identifier}-rds-sg"
  description = "Security group for RDS PostgreSQL instance"
  vpc_id      = var.config.vpc_id

  # Allow PostgreSQL access from ECS tasks
  ingress {
    description     = "PostgreSQL from ECS"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.config.ecs_security_group_id]
  }

  # No outbound rules needed for RDS (it doesn't initiate connections)
  egress {
    description = "No outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.config.identifier}-rds-sg"
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}

# RDS PostgreSQL Instance
resource "aws_db_instance" "main" {
  identifier     = var.config.identifier
  engine         = "postgres"
  engine_version = var.config.engine_version
  instance_class = var.config.instance_class

  # Storage configuration
  allocated_storage = var.config.allocated_storage
  storage_type      = "gp2"
  storage_encrypted = true

  # Database configuration
  db_name  = var.config.database_name
  username = var.config.master_username
  password = var.config.master_password

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Single-AZ configuration for development
  multi_az = false

  # Backup configuration
  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "mon:04:00-mon:05:00"

  # Disable deletion protection for development
  deletion_protection = false
  skip_final_snapshot = true

  tags = {
    Name        = var.config.identifier
    Environment = var.config.environment
    ManagedBy   = "terraform"
  }
}
