# ==============================================================================
# 파일명: provider.tf
# 설명: 프로바이더 요구사항 및 AWS 리전/공통 태그 설정
# ==============================================================================

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "CloudRetail-Enterprise"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
