#!/bin/bash

set -e

echo "🚀 Setting up DevOps Observability Stack with Docker Compose..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed. Please install Docker first."
    exit 1
fi

# Check for Docker Compose (both old and new syntax)
if command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE="docker-compose"
    echo "✅ Using docker-compose (legacy)"
elif docker compose version &> /dev/null; then
    DOCKER_COMPOSE="docker compose"
    echo "✅ Using docker compose (modern)"
else
    echo "❌ Docker Compose is not available. Please install Docker Compose."
    echo "For installation instructions, visit: https://docs.docker.com/compose/install/"
    exit 1
fi

# Create necessary directories
echo "📁 Creating directories..."
mkdir -p monitoring/prometheus
mkdir -p monitoring/grafana/provisioning/dashboards
mkdir -p monitoring/grafana/provisioning/datasources
mkdir -p services/database

# Build and start services
echo "🔨 Building and starting services..."
$DOCKER_COMPOSE up -d --build

# Wait for services to be healthy
echo "⏳ Waiting for services to be healthy (30 seconds)..."
sleep 30

# Check service health
echo ""
echo "🏥 Checking service health..."
echo ""
echo "Product Service:"
curl -s http://localhost:5000/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  ⏳ Not ready yet, wait a bit longer..."

echo ""
echo "Order Service:"
curl -s http://localhost:5001/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  ⏳ Not ready yet, wait a bit longer..."

echo ""
echo "User Service:"
curl -s http://localhost:5002/health 2>/dev/null | python3 -m json.tool 2>/dev/null || echo "  ⏳ Not ready yet, wait a bit longer..."

echo ""
echo "✅ Setup complete!"
echo ""
echo "=========================================="
echo "📊 Access the following URLs:"
echo "=========================================="
echo "  🛍️  Product Service: http://localhost:5000/products"
echo "  📦  Order Service:   http://localhost:5001/orders"
echo "  👤  User Service:    http://localhost:5002/users"
echo "  📈  Prometheus:      http://localhost:9090"
echo "  📊  Grafana:         http://localhost:3000 (admin/admin)"
echo "  🔍  Kibana:          http://localhost:5601"
echo ""
echo "=========================================="
echo "📝 Useful Commands:"
echo "=========================================="
echo "  View logs:           $DOCKER_COMPOSE logs -f"
echo "  Stop services:       $DOCKER_COMPOSE down"
echo "  Restart services:    $DOCKER_COMPOSE restart"
echo "  View containers:     docker ps"
echo ""
