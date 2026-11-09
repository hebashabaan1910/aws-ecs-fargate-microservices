variable "aws_region" {
  description = "AWS region for resources deployment"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment identifier (e.g. dev, staging, production)"
  type        = string
  default     = "production"
}

variable "project_name" {
  description = "Prefix for resources in this project"
  type        = string
  default     = "microservices-fargate"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones to deploy subnets into"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private app subnets (ECS tasks)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for private database subnets (ElastiCache)"
  type        = list(string)
  default     = ["10.0.20.0/24", "10.0.21.0/24"]
}

variable "fargate_cpu" {
  description = "Fargate CPU units (256 = 0.25 vCPU, 512 = 0.5 vCPU, 1024 = 1 vCPU)"
  type        = number
  default     = 256
}

variable "fargate_memory" {
  description = "Fargate Memory (MB)"
  type        = number
  default     = 512
}

variable "app_count" {
  description = "Number of task replicas per service"
  type        = number
  default     = 2
}

variable "jwt_secret_value" {
  description = "Default secret value for JWT signing (stored in Secrets Manager)"
  type        = string
  default     = "SuperSecretEnterpriseJWTKeyChangeInProduction32Chars"
  sensitive   = true
}

