# AWS Secrets Manager for Secure Runtime Credential Injection

resource "aws_secretsmanager_secret" "jwt_secret" {
  name                    = "${var.project_name}/jwt-secret"
  description             = "JWT Secret Key used by Auth microservice"
  recovery_window_in_days = 0 # Immediate deletion on destroy for lab/testing simplicity

  tags = {
    Name = "${var.project_name}-jwt-secret"
  }
}

resource "aws_secretsmanager_secret_version" "jwt_secret_val" {
  secret_id     = aws_secretsmanager_secret.jwt_secret.id
  secret_string = var.jwt_secret_value
}

# App Config / Database Secret
resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}/app-config"
  description             = "Application secrets (Redis Auth and service tokens)"
  recovery_window_in_days = 0

  tags = {
    Name = "${var.project_name}-app-config"
  }
}

resource "aws_secretsmanager_secret_version" "app_secrets_val" {
  secret_id = aws_secretsmanager_secret.app_secrets.id
  secret_string = jsonencode({
    REDIS_PASSWORD = ""
    API_KEY        = "production-internal-mesh-key"
  })
}

