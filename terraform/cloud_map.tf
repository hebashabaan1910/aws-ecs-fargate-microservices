# AWS Cloud Map (Service Discovery) for Internal Microservices Communication

# Private DNS Namespace linked to the VPC
resource "aws_service_discovery_private_dns_namespace" "internal" {
  name        = "production.local"
  description = "Private DNS namespace for ECS microservices inter-service discovery"
  vpc         = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-cloud-map-ns"
  }
}

# Service Discovery Registration for Auth Service
resource "aws_service_discovery_service" "auth" {
  name = "auth"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-sd-auth"
  }
}

# Service Discovery Registration for Orders Service
resource "aws_service_discovery_service" "orders" {
  name = "orders"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-sd-orders"
  }
}

# Service Discovery Registration for Notifications Service
resource "aws_service_discovery_service" "notifications" {
  name = "notifications"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.internal.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  health_check_custom_config {
    failure_threshold = 1
  }

  tags = {
    Name = "${var.project_name}-sd-notifications"
  }
}

