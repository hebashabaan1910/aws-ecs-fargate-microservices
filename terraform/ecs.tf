# Amazon ECS Cluster and Fargate Services

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Name = "${var.project_name}-ecs-cluster"
  }
}

# -------------------------------------------------------------
# CloudWatch Log Groups for Microservices & X-Ray Sidecars
# -------------------------------------------------------------
resource "aws_cloudwatch_log_group" "auth_logs" {
  name              = "/ecs/${var.project_name}/auth"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "orders_logs" {
  name              = "/ecs/${var.project_name}/orders"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "notifications_logs" {
  name              = "/ecs/${var.project_name}/notifications"
  retention_in_days = 7
}

resource "aws_cloudwatch_log_group" "xray_logs" {
  name              = "/ecs/${var.project_name}/xray"
  retention_in_days = 7
}

# -------------------------------------------------------------
# Task Definition: Auth Service
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "auth" {
  family                   = "${var.project_name}-auth"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "auth-service"
      image     = "${aws_ecr_repository.services["auth-service"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3000
          hostPort      = 3000
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3000" },
        { name = "SERVICE_NAME", value = "auth-service" },
        { name = "REDIS_HOST", value = aws_elasticache_replication_group.redis.primary_endpoint_address },
        { name = "REDIS_PORT", value = "6379" },
        { name = "ENABLE_XRAY", value = "true" },
        { name = "AWS_XRAY_DAEMON_ADDRESS", value = "127.0.0.1:2000" }
      ]

      secrets = [
        {
          name      = "JWT_SECRET"
          valueFrom = aws_secretsmanager_secret.jwt_secret.arn
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.auth_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "auth"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = false
      cpu       = 32
      memory    = 64

      portMappings = [
        {
          containerPort = 2000
          hostPort      = 2000
          protocol      = "udp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.xray_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ])

  tags = {
    Service = "auth"
  }
}

# -------------------------------------------------------------
# Task Definition: Orders Service
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "orders" {
  family                   = "${var.project_name}-orders"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "orders-service"
      image     = "${aws_ecr_repository.services["orders-service"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3001
          hostPort      = 3001
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3001" },
        { name = "SERVICE_NAME", value = "orders-service" },
        { name = "AUTH_SERVICE_URL", value = "http://auth.production.local:3000" },
        { name = "NOTIFICATIONS_SERVICE_URL", value = "http://notifications.production.local:3002" },
        { name = "ENABLE_XRAY", value = "true" },
        { name = "AWS_XRAY_DAEMON_ADDRESS", value = "127.0.0.1:2000" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.orders_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "orders"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = false
      cpu       = 32
      memory    = 64

      portMappings = [
        {
          containerPort = 2000
          hostPort      = 2000
          protocol      = "udp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.xray_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ])

  tags = {
    Service = "orders"
  }
}

# -------------------------------------------------------------
# Task Definition: Notifications Service
# -------------------------------------------------------------
resource "aws_ecs_task_definition" "notifications" {
  family                   = "${var.project_name}-notifications"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = tostring(var.fargate_cpu)
  memory                   = tostring(var.fargate_memory)
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "notifications-service"
      image     = "${aws_ecr_repository.services["notifications-service"].repository_url}:latest"
      essential = true

      portMappings = [
        {
          containerPort = 3002
          hostPort      = 3002
          protocol      = "tcp"
        }
      ]

      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "3002" },
        { name = "SERVICE_NAME", value = "notifications-service" },
        { name = "ENABLE_XRAY", value = "true" },
        { name = "AWS_XRAY_DAEMON_ADDRESS", value = "127.0.0.1:2000" }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.notifications_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "notifications"
        }
      }
    },
    {
      name      = "xray-daemon"
      image     = "public.ecr.aws/xray/aws-xray-daemon:latest"
      essential = false
      cpu       = 32
      memory    = 64

      portMappings = [
        {
          containerPort = 2000
          hostPort      = 2000
          protocol      = "udp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.xray_logs.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "xray"
        }
      }
    }
  ])

  tags = {
    Service = "notifications"
  }
}

# -------------------------------------------------------------
# ECS Service: Auth Service (with Blue/Green Deployment Controller)
# -------------------------------------------------------------
resource "aws_ecs_service" "auth" {
  name            = "${var.project_name}-auth"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.auth.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.auth_blue.arn
    container_name   = "auth-service"
    container_port   = 3000
  }

  service_registries {
    registry_arn = aws_service_discovery_service.auth.arn
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Service = "auth"
  }
}

# -------------------------------------------------------------
# ECS Service: Orders Service
# -------------------------------------------------------------
resource "aws_ecs_service" "orders" {
  name            = "${var.project_name}-orders"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.orders.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.orders_blue.arn
    container_name   = "orders-service"
    container_port   = 3001
  }

  service_registries {
    registry_arn = aws_service_discovery_service.orders.arn
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Service = "orders"
  }
}

# -------------------------------------------------------------
# ECS Service: Notifications Service
# -------------------------------------------------------------
resource "aws_ecs_service" "notifications" {
  name            = "${var.project_name}-notifications"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.notifications.arn
  desired_count   = var.app_count
  launch_type     = "FARGATE"

  network_configuration {
    security_groups  = [aws_security_group.ecs_sg.id]
    subnets          = aws_subnet.private[*].id
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.notifications_blue.arn
    container_name   = "notifications-service"
    container_port   = 3002
  }

  service_registries {
    registry_arn = aws_service_discovery_service.notifications.arn
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [
      task_definition,
      load_balancer
    ]
  }

  depends_on = [aws_lb_listener.http]

  tags = {
    Service = "notifications"
  }
}

