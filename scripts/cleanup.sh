#!/bin/bash

echo "🧹 Cleaning up DevOps Observability Stack..."

# Detect Docker Compose command
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Docker Compose not found"
    exit 1
fi

# Stop and remove containers
$DOCKER_COMPOSE down -v

# Remove dangling images
docker image prune -f

echo "✅ Cleanup complete!"
