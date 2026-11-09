#!/usr/bin/env bash
# ==============================================================================
# Teardown Script for ECS Fargate Microservices
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo "============================================================"
echo " AWS ECS Fargate Microservices - Resource Teardown"
echo "============================================================"

# Stop local containers if running
if command -v docker compose &> /dev/null; then
  echo "Stopping local Docker Compose containers..."
  docker compose -f "$SCRIPT_DIR/../docker-compose.yml" down -v || true
fi

# Destroy AWS resources
cd "$TERRAFORM_DIR"
if [ -d ".terraform" ]; then
  read -p "⚠️  Are you sure you want to DESTROY all AWS resources via Terraform? (y/N): " -r CONFIRM
  if [[ $CONFIRM =~ ^[Yy]$ ]]; then
    echo "Destroying AWS resources..."
    terraform destroy -auto-approve
    echo "✅ AWS resources successfully destroyed."
  else
    echo "Cloud teardown cancelled."
  fi
fi

