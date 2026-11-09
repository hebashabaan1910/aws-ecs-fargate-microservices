#!/usr/bin/env python3
import subprocess
import boto3
import base64
import sys

REGION = 'us-east-1'
ACCOUNT_ID = '992483131200'
REGISTRY = f"{ACCOUNT_ID}.dkr.ecr.{REGION}.amazonaws.com"

print(f"1. Authenticating Docker to Amazon ECR ({REGISTRY})...")
ecr = boto3.client('ecr', region_name=REGION)
res = ecr.get_authorization_token()
auth_data = res['authorizationData'][0]
token = base64.b64decode(auth_data['authorizationToken']).decode('utf-8')
username, password = token.split(':')

login_proc = subprocess.run(
    ['docker', 'login', '--username', username, '--password-stdin', REGISTRY],
    input=password.encode('utf-8'),
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE
)

if login_proc.returncode != 0:
    print("Docker login failed:", login_proc.stderr.decode('utf-8'))
    sys.exit(1)

print("Docker login to ECR succeeded!")

SERVICES = ['auth', 'orders', 'notifications']

for svc in SERVICES:
    local_image = f"aws-project-{svc}:latest"
    remote_repo = f"{REGISTRY}/microservices-fargate/{svc}-service"
    remote_tag = f"{remote_repo}:latest"
    
    print(f"\nTagging {local_image} -> {remote_tag}...")
    tag_proc = subprocess.run(['docker', 'tag', local_image, remote_tag])
    if tag_proc.returncode != 0:
        print(f"Failed to tag {local_image}")
        sys.exit(1)
        
    print(f"Pushing {remote_tag} to Amazon ECR...")
    push_proc = subprocess.run(['docker', 'push', remote_tag])
    if push_proc.returncode != 0:
        print(f"Failed to push {remote_tag}")
        sys.exit(1)

print("\nAll 3 microservice images successfully pushed to Amazon ECR!")
