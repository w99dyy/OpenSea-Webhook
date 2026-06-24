#!/bin/bash
set -e

IMAGE="ghcr.io/w99dyy/opensea-webhook:latest"
VPS="root@212.227.161.11"
CONTAINER="opensea-webhook"
ENV_PATH="/app/opensea-webhook/.env"

echo "Building..."
docker build -t $IMAGE .

echo "Pushing to GHCR..."
docker push $IMAGE

echo "Syncing .env..."
ssh $VPS "mkdir -p /app/opensea-webhook"
scp .env $VPS:$ENV_PATH

echo "Deploying..."
ssh $VPS "
  docker pull $IMAGE &&
  docker stop $CONTAINER || true &&
  docker rm $CONTAINER || true &&
  docker run -d \
    --name $CONTAINER \
    --restart unless-stopped \
    --env-file $ENV_PATH \
    $IMAGE
"

echo "✅ Done!"
