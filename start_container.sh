#!/bin/bash
set -ex
# start_container.sh

# ---------------------------------------------------------------------
# NOTE:
# This script is anonymized for public sharing.
# Replace placeholders with your own values:
#   - R_PASSWORD
#   - AWS_REGION
#   - WORKSPACE_DIR
#   - S3_BUCKET
# Provide AWS credentials via environment variables, IAM roles, or AWS CLI config.
# ---------------------------------------------------------------------

CONTAINER_NAME="rstudio-workspace"
IMAGE_NAME="rstudio-image:s3-ready"
R_PASSWORD="YOUR_R_PASSWORD"
AWS_REGION="YOUR_AWS_REGION"
WORKSPACE_DIR="$HOME/rstudio_workspace"
S3_BUCKET="YOUR_S3_BUCKET"

#--------------Fetch Temporary AWS credentials (IMDSv2)-------------------
echo ""
echo "Fetching temporary AWS credentials..."
echo ""

# Get IMDSv2 token
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
echo "IMDSv2 token fetched"

# Get IAM role
ROLE_NAME=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/iam/security-credentials/)
echo "IAM role: $ROLE_NAME"

# Fetch temporary credentials
CREDS=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
    http://169.254.169.254/latest/meta-data/iam/security-credentials/$ROLE_NAME)

# Export environment variables
export AWS_ACCESS_KEY_ID=$(echo $CREDS | jq -r .AccessKeyId)
export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | jq -r .SecretAccessKey)
export AWS_SESSION_TOKEN=$(echo $CREDS | jq -r .Token)
export AWS_DEFAULT_REGION=$AWS_REGION
echo "AWS credentials exported"

# Ensure local workspace exists
mkdir -p $WORKSPACE_DIR

# Sync from S3
echo "Syncing workspace from S3..."
aws s3 sync s3://$S3_BUCKET $WORKSPACE_DIR
echo "S3 sync complete"

# --- Remove any old container ---
if [ "$(docker ps -aq -f name=$CONTAINER_NAME)" ]; then
    echo "Removing old container..."
    docker rm -f $CONTAINER_NAME
fi

# --- Launch container ---
echo "Starting container $CONTAINER_NAME..."
docker run -d \
    --name $CONTAINER_NAME \
    -p 8787:8787 \
    -p 8888:8888 \
    -v $WORKSPACE_DIR:/home/rstudio/work \
    -e PASSWORD=$R_PASSWORD \
    -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID \
    -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
    -e AWS_SESSION_TOKEN=$AWS_SESSION_TOKEN \
    -e AWS_DEFAULT_REGION=$AWS_REGION \
    $IMAGE_NAME

# Fetch public IP
PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
http://169.254.169.254/latest/meta-data/public-ipv4)

echo ""
echo "Container started"
echo "RStudio: http://$PUBLIC_IP:8787"
echo "Jupyter: http://$PUBLIC_IP:8888"
echo "Use password: $R_PASSWORD"
echo ""

