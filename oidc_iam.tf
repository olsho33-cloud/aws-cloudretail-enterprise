# ==============================================================================
# 파일명: oidc_iam.tf
# 설명: GitHub Actions OIDC 기반 AWS 임시 자격 증명(STS) 연동 설정
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. GitHub OIDC Identity Provider 생성
# ------------------------------------------------------------------------------
# [약속된 명령어] resource "aws_iam_openid_connect_provider"
resource "aws_iam_openid_connect_provider" "github" {
  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  # GitHub OIDC 서버 SSL 지문(Thumbprint)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a21d81e5b274704812b1acd3140501386187"
  ]
}

# ------------------------------------------------------------------------------
# 2. GitHub Actions 전용 IAM Role & Trust Policy
# ------------------------------------------------------------------------------
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-${var.environment}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
          StringLike = {
            # [★실무 핵심] 지정한 GitHub 리포지토리에서 온 파이프라인 요청만 인가
            "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
          }
        }
      }
    ]
  })
}

# ------------------------------------------------------------------------------
# 3. IAM Policy 바인딩 (인프라 프로비저닝 권한)
# ------------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "github_actions_admin" {
  role       = aws_iam_role.github_actions.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# ------------------------------------------------------------------------------
# 4. Output 선언 (GitHub Secrets 등록용)
# ------------------------------------------------------------------------------
output "github_actions_role_arn" {
  value       = aws_iam_role.github_actions.arn
  description = "GitHub Actions Workflow의 AWS_ROLE_ARN에 등록할 IAM Role ARN입니다."
}
