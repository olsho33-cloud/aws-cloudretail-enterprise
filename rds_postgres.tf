# ==============================================================================
# 파일명: rds_postgres.tf
# 설명: Database Subnet Group 및 Multi-AZ PostgreSQL RDS 구축
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. DB Subnet Group (Database Subnet A, C 묶음)
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "${var.project_name}-${var.environment}-db-subnet-group"
  subnet_ids = [aws_subnet.db_a.id, aws_subnet.db_c.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-db-subnet-group"
  }
}

# ------------------------------------------------------------------------------
# 2. Random DB Password 생성
# ------------------------------------------------------------------------------
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ------------------------------------------------------------------------------
# 3. Multi-AZ PostgreSQL RDS Instance
# ------------------------------------------------------------------------------
resource "aws_db_instance" "postgres" {
  identifier        = "${var.project_name}-${var.environment}-postgres"
  engine            = "postgres"
  engine_version    = "15" # [수정] 메이저 버전 지정하여 호환성 확보
  instance_class    = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type          = "gp3"
  storage_encrypted     = true

  db_name  = "cloudretail"
  username = "appuser"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.db.id]

  multi_az            = true
  publicly_accessible = false

  backup_retention_period = 1
  skip_final_snapshot     = true

  tags = {
    Name = "${var.project_name}-${var.environment}-postgres"
  }
}

# ------------------------------------------------------------------------------
# 4. Outputs
# ------------------------------------------------------------------------------
output "rds_endpoint" {
  value       = aws_db_instance.postgres.endpoint
  description = "PostgreSQL DB 엔드포인트 주소입니다."
}

output "rds_db_name" {
  value       = aws_db_instance.postgres.db_name
  description = "PostgreSQL 기본 데이터베이스 이름입니다."
}
