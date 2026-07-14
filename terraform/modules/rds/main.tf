# Module: RDS PostgreSQL — Database riêng, giữ data qua destroy
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-rds-subnet"
  subnet_ids = var.private_subnet_ids
}

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL from K8s nodes"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = var.allowed_sg_ids
  }

  tags = { Name = "${var.project_name}-rds-sg" }
}

resource "aws_db_instance" "main" {
  identifier = "${var.project_name}-postgres"

  engine         = "postgres"
  engine_version = "16"
  instance_class = var.instance_class

  db_name  = var.db_name
  username = var.db_user
  password = var.db_password

  storage_type          = "gp3"
  allocated_storage     = var.storage_size
  max_allocated_storage = var.max_storage_size

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]

  multi_az               = false
  publicly_accessible    = false
  skip_final_snapshot    = true
  backup_retention_period = 7
  deletion_protection    = false

  tags = { Name = "${var.project_name}-rds" }
}
