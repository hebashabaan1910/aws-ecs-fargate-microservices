# Application Load Balancer (ALB) and Path-Based Routing

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-alb"
  }
}

# -------------------------------------------------------------
# Target Groups: Auth Service (Blue & Green for CodeDeploy)
# -------------------------------------------------------------
resource "aws_lb_target_group" "auth_blue" {
  name        = "mf-auth-blue"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "3000"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "auth"
    Slot    = "blue"
  }
}

resource "aws_lb_target_group" "auth_green" {
  name        = "mf-auth-green"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "3000"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "auth"
    Slot    = "green"
  }
}

# -------------------------------------------------------------
# Target Groups: Orders Service (Blue & Green for CodeDeploy)
# -------------------------------------------------------------
resource "aws_lb_target_group" "orders_blue" {
  name        = "mf-orders-blue"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "3001"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "orders"
    Slot    = "blue"
  }
}

resource "aws_lb_target_group" "orders_green" {
  name        = "mf-orders-green"
  port        = 3001
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "3001"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "orders"
    Slot    = "green"
  }
}

# --------------------------------------------------------------------
# Target Groups: Notifications Service (Blue & Green for CodeDeploy)
# --------------------------------------------------------------------
resource "aws_lb_target_group" "notifications_blue" {
  name        = "mf-notif-blue"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "3002"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "notifications"
    Slot    = "blue"
  }
}

resource "aws_lb_target_group" "notifications_green" {
  name        = "mf-notif-green"
  port        = 3002
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path                = "/health"
    port                = "3002"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Service = "notifications"
    Slot    = "green"
  }
}

# -------------------------------------------------------------
# ALB Production Listener (Port 80)
# -------------------------------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "application/json"
      message_body = "{\"status\": \"ok\", \"message\": \"AWS ECS Fargate Microservices Gateway Online\", \"endpoints\": [\"/api/auth/*\", \"/api/orders/*\", \"/api/notifications/*\"]}"
      status_code  = "200"
    }
  }
}

# -------------------------------------------------------------
# ALB Test Listener (Port 8080) for CodeDeploy Traffic Shifting
# -------------------------------------------------------------
resource "aws_lb_listener" "test" {
  load_balancer_arn = aws_lb.main.arn
  port              = 8080
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_green.arn
  }
}

# -------------------------------------------------------------
# Path-Based Routing Rules on Production Listener
# -------------------------------------------------------------
resource "aws_lb_listener_rule" "auth_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 10

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.auth_blue.arn
  }

  condition {
    path_pattern {
      values = ["/api/auth/*", "/api/auth"]
    }
  }
}

resource "aws_lb_listener_rule" "orders_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 20

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.orders_blue.arn
  }

  condition {
    path_pattern {
      values = ["/api/orders/*", "/api/orders"]
    }
  }
}

resource "aws_lb_listener_rule" "notifications_rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 30

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.notifications_blue.arn
  }

  condition {
    path_pattern {
      values = ["/api/notifications/*", "/api/notifications"]
    }
  }
}

