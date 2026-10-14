# ==============================================================================
# 파일명: app_alb_ecs.tf
# 설명: Private Subnet 전용 ECS Fargate 서비스, ECR 및 Multi-AZ ALB 구축
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. Amazon ECR Repository (컨테이너 이미지 저장소)
# ------------------------------------------------------------------------------
resource "aws_ecr_repository" "api" {
  name                 = "${var.project_name}-${var.environment}-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ------------------------------------------------------------------------------
# 2. Application Load Balancer (Public Subnet A, C 배치)
# ------------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_c.id]

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

resource "aws_lb_target_group" "api" {
  name        = "${var.project_name}-${var.environment}-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }
}

# ------------------------------------------------------------------------------
# 3. ECS IAM Task Execution Role
# ------------------------------------------------------------------------------
resource "aws_iam_role" "ecs_exec" {
  name = "${var.project_name}-${var.environment}-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_exec_attach" {
  role       = aws_iam_role.ecs_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ------------------------------------------------------------------------------
# 4. ECS Cluster & CloudWatch Log Group
# ------------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/${var.project_name}-${var.environment}"
  retention_in_days = 7
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-${var.environment}-cluster"
}

# ------------------------------------------------------------------------------
# 5. ECS Task Definition (Private Subnet 내 구동)
# ------------------------------------------------------------------------------
resource "aws_ecs_task_definition" "api" {
  family                   = "${var.project_name}-${var.environment}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_exec.arn

  container_definitions = jsonencode([
    {
      name      = "api"
      image     = "python:3.11-slim"
      essential = true

      command = [
        "python3", "-c",
        "from http.server import HTTPServer, BaseHTTPRequestHandler\nimport os, json\nclass S(BaseHTTPRequestHandler):\n def do_GET(self):\n  if self.path == '/health':\n   self.send_response(200); self.send_header('Content-type', 'application/json'); self.end_headers(); self.wfile.write(json.dumps({'status':'healthy', 'tier':'3-tier-private-ecs'}).encode('utf-8'))\n  else:\n   self.send_response(404); self.end_headers()\nHttpserver = HTTPServer(('0.0.0.0', 8080), S)\nHttpserver.serve_forever()"
      ]

      portMappings = [{
        containerPort = 8080
        hostPort      = 8080
      }]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

# ------------------------------------------------------------------------------
# 6. ECS Service (Private Subnet Multi-AZ 배치)
# ------------------------------------------------------------------------------
resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-${var.environment}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.api.arn
  desired_count   = 2 # Multi-AZ 고가용성을 위해 2개 컨테이너 가동
  launch_type     = "FARGATE"

  network_configuration {
    # [★실무 핵심] 외부 접근이 차단된 Private Subnet A, C에 배치
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_c.id]
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false # Public IP를 부여하지 않음 (NAT GW를 이용한 인터넷 통신)
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.api.arn
    container_name   = "api"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.http]
}

# ------------------------------------------------------------------------------
# 7. Outputs (ALB DNS 및 ECR URL)
# ------------------------------------------------------------------------------
output "alb_dns_name" {
  value       = aws_lb.main.dns_name
  description = "Public ALB 엔드포인트 주소입니다."
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.api.repository_url
  description = "ECR 리포지토리 URL입니다."
}
