#!/bin/bash
set -e

IMAGE="ghcr.io/w99dyy/opensea-webhook:latest"
VPS="root@212.227.161.11"

echo "Building..."
docker build -t $IMAGE .

echo "Pushing to GHCR..."
docker push $IMAGE

echo "Syncing env file..."
scp .env $VPS:/app/opensea-webhook/.env   # ← copies local .env to VPS

echo "Deploying to VPS..."
ssh $VPS "
  echo $GITHUB_TOKEN | docker login ghcr.io -u w99dyy --password-stdin &&
  docker pull $IMAGE &&
  docker stop opensea-bot || true &&
  docker rm opensea-bot || true &&
  docker run -d \
    --name opensea-bot \
    --restart unless-stopped \
    --env-file /app/opensea-bot/.env \
    $IMAGE
"

echo "✅ Done!"
