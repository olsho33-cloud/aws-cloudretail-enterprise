# ==============================================================================
# 파일명: backend_setup.tf
# 설명: Remote State (S3) 및 State Locking (DynamoDB) 인프라 생성
# ==============================================================================

resource "random_string" "tf_suffix" {
  length  = 6
  special = false
  upper   = false
}

# 1. Remote State 저장용 S3 버킷
resource "aws_s3_bucket" "tf_state" {
  bucket        = "${var.project_name}-${var.environment}-tfstate-${random_string.tf_suffix.result}"
  force_destroy = true

  tags = {
    Name = "${var.project_name}-${var.environment}-tfstate"
  }
}

resource "aws_s3_bucket_versioning" "tf_state_ver" {
  bucket = aws_s3_bucket.tf_state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state_enc" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state_pab" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 2. State Locking 전용 DynamoDB 테이블
resource "aws_dynamodb_table" "tf_locks" {
  name         = "${var.project_name}-${var.environment}-tflocks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tflocks"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.tf_state.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.tf_locks.name
}
