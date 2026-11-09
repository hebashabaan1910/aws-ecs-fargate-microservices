output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "Public DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "cloud_map_namespace" {
  description = "AWS Cloud Map private DNS namespace"
  value       = aws_service_discovery_private_dns_namespace.internal.name
}

output "ecr_repositories" {
  description = "ECR Repository URLs"
  value = {
    for k, v in aws_ecr_repository.services : k => v.repository_url
  }
}

output "redis_primary_endpoint" {
  description = "ElastiCache Redis Primary Endpoint Address"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}

output "ecs_cluster_name" {
  description = "ECS Cluster Name"
  value       = aws_ecs_cluster.main.name
}

output "secrets_manager_jwt_arn" {
  description = "ARN of Secrets Manager JWT Secret"
  value       = aws_secretsmanager_secret.jwt_secret.arn
}

output "codepipeline_name" {
  description = "Name of the CodePipeline CI/CD pipeline"
  value       = aws_codepipeline.pipeline.name
}

