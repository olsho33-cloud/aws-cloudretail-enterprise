# ==============================================================================
# 파일명: variables.tf
# 설명: 엔터프라이즈 프로젝트 전역 변수 선언
# ==============================================================================

variable "aws_region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "environment" {
  description = "배포 환경 (dev, stage, prod)"
  type        = string
  default     = "prod"
}

variable "project_name" {
  description = "프로젝트 식별자"
  type        = string
  default     = "cloudretail-ent"
}

variable "github_repository" {
  description = "GitHub 계정명/리포지토리명"
  type        = string
  default     = "olsho33-cloud/aws-cloudretail-enterprise" # [본인 계정명 확인]
}
