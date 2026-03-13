#!/bin/bash
set -e
# ---------------------------------------------------------------------
# NOTE:
# This script is anonymized for public sharing.
# Replace the placeholders below with your own values:
#   - WORKSPACE_DIR
#   - S3_BUCKET
#   - AWS_REGION
# Provide AWS credentials via environment variables, IAM roles, or AWS CLI config.
# Do NOT hardcode secrets in public repositories.
# ---------------------------------------------------------------------

CONTAINER_NAME="rstudio-workspace"
WORKSPACE_DIR="$HOME/rstudio_workspace"
S3_BUCKET="YOUR_S3_BUCKET"
AWS_REGION="YOUR_AWS_REGION"

echo "Fetching AWS credentials for S3 sync..."

# Get IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
-H "X-aws-ec2-metadata-token-ttl-seconds: 21600")

# Get IAM role
ROLE_NAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/iam/security-credentials/)

# Fetch temporary credentials
CREDS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)

# Export environment variables
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Token)
export AWS_DEFAULT_REGION=$AWS_REGION

# Check if the container is running
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Stopping running container $CONTAINER_NAME..."
    docker stop $CONTAINER_NAME || true
fi

# Optional: commit a snapshot of the container (uncomment to enable)
# echo "Saving a snapshot of the container..."
# docker commit $CONTAINER_NAME rstudio-image:session-$(date +%Y%m%d-%H%M)

# Sync workspace to S3
echo "Syncing local workspace back to S3 bucket $S3_BUCKET..."
aws s3 sync $WORKSPACE_DIR s3://$S3_BUCKET

echo "Cleanup complete. Container is stopped and workspace synced."
