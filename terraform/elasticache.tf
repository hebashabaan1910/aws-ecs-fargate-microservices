# Amazon ElastiCache (Redis) for Shared Session and Token Cache

# ElastiCache Subnet Group (Private Database Subnets)
resource "aws_elasticache_subnet_group" "redis" {
  name        = "${var.project_name}-redis-subnet-group"
  description = "Subnets for ElastiCache Redis cluster"
  subnet_ids  = aws_subnet.database[*].id
}

# Parameter Group for Redis 7.x
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.project_name}-redis7-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "volatile-lru"
  }
}

# ElastiCache Replication Group (Redis)
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project_name}-redis"
  description                = "Shared Redis session store for microservices"
  node_type                  = "cache.t4g.micro"
  num_cache_clusters         = 2
  parameter_group_name       = aws_elasticache_parameter_group.redis.name
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis_sg.id]
  automatic_failover_enabled = true
  multi_az_enabled           = true
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false # Set to true when AUTH token is configured
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = {
    Name = "${var.project_name}-redis-cluster"
  }
}
