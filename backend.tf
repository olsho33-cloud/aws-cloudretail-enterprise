# ==============================================================================
# 파일명: backend.tf
# 설명: S3 Remote State 및 DynamoDB State Locking 설정
# ==============================================================================

terraform {
  backend "s3" {
    bucket         = "cloudretail-ent-prod-tfstate-v6esxt"
    key            = "enterprise/prod/terraform.tfstate"
    region         = "ap-northeast-2"
    dynamodb_table = "cloudretail-ent-prod-tflocks"
    encrypt        = true
  }
}
