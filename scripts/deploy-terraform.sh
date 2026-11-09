#!/usr/bin/env bash
# ==============================================================================
# Terraform Deployment Helper for ECS Fargate Microservices
# ==============================================================================
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$SCRIPT_DIR/../terraform"

echo "============================================================"
echo " AWS ECS Fargate Microservices - Infrastructure Deployment"
echo "============================================================"

# Check AWS CLI authentication
if ! command -v aws &> /dev/null; then
  echo "⚠️  AWS CLI is not installed or not in PATH."
  echo "    Ensure your AWS credentials are configured before applying to AWS."
else
  echo "Verifying AWS credentials..."
  aws sts get-caller-identity || { echo "❌ AWS authentication failed. Run 'aws configure' first."; exit 1; }
fi

cd "$TERRAFORM_DIR"

echo -e "\n1. Initializing Terraform..."
terraform init

echo -e "\n2. Validating Terraform configuration..."
terraform validate

echo -e "\n3. Generating execution plan..."
terraform plan -out=tfplan

echo -e "\n------------------------------------------------------------"
read -p "Do you want to apply this Terraform plan to AWS? (y/N): " -r CONFIRM
if [[ $CONFIRM =~ ^[Yy]$ ]]; then
  echo -e "\nApplying Terraform changes..."
  terraform apply "tfplan"
  echo "✅ Infrastructure provisioned successfully!"
else
  echo "Deployment aborted by user. The plan was not applied."
fi

