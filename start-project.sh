#!/bin/bash
# ============================================
# Start Complete DevOps Observability Stack
# ============================================

set -e

echo "🚀 Starting Complete DevOps Observability Stack"
echo "================================================"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }

# ─────────────────────────────────────────
# STEP 1: Start Minikube
# ─────────────────────────────────────────
echo ""
echo "📋 Step 1: Checking Minikube..."
if ! minikube status | grep -q "Running"; then
    echo "Starting Minikube..."
    minikube start
    print_status "Minikube started!"
else
    print_status "Minikube already running!"
fi

# ─────────────────────────────────────────
# STEP 2: Start Docker Compose Stack
# ─────────────────────────────────────────
echo ""
echo "📋 Step 2: Starting Docker Compose Stack..."
cd ~/devops-observability-stack
docker compose up -d
print_status "Docker Compose stack started!"

echo "⏳ Waiting for Docker services to be healthy..."
sleep 15

# ─────────────────────────────────────────
# STEP 3: Apply Kubernetes Manifests
# ─────────────────────────────────────────
echo ""
echo "📋 Step 3: Applying Kubernetes manifests..."

kubectl apply -f k8s/namespace/namespace.yaml
kubectl apply -f k8s/configmap/configmap.yaml
kubectl apply -f k8s/secrets/secrets.yaml
kubectl apply -f k8s/deployments/postgres.yaml
kubectl apply -f k8s/deployments/product-service.yaml
kubectl apply -f k8s/deployments/order-service.yaml
kubectl apply -f k8s/deployments/user-service.yaml
kubectl apply -f k8s/hpa/hpa.yaml
print_status "Kubernetes manifests applied!"

# ─────────────────────────────────────────
# STEP 4: Set Correct Images (docker.io prefix)
# ─────────────────────────────────────────
echo ""
echo "📋 Step 4: Setting correct image names..."

kubectl set image deployment/product-service \
  product-service=docker.io/pawanm2307/product-service:v1.0.0 \
  -n ecommerce 2>/dev/null || true

kubectl set image deployment/order-service \
  order-service=docker.io/pawanm2307/order-service:v1.0.0 \
  -n ecommerce 2>/dev/null || true

kubectl set image deployment/user-service \
  user-service=docker.io/pawanm2307/user-service:v1.0.0 \
  -n ecommerce 2>/dev/null || true

print_status "Image names updated!"

# ─────────────────────────────────────────
# STEP 5: Set imagePullPolicy to Never
# ─────────────────────────────────────────
echo ""
echo "📋 Step 5: Configuring image pull policy..."

kubectl patch deployment product-service -n ecommerce \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"product-service","imagePullPolicy":"Never"}]}}}}' \
  2>/dev/null || true

kubectl patch deployment order-service -n ecommerce \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"order-service","imagePullPolicy":"Never"}]}}}}' \
  2>/dev/null || true

kubectl patch deployment user-service -n ecommerce \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","imagePullPolicy":"Never"}]}}}}' \
  2>/dev/null || true

print_status "Image pull policy set to Never (uses local minikube images)!"

# ─────────────────────────────────────────
# STEP 6: Wait for Pods to be Ready
# ─────────────────────────────────────────
echo ""
echo "⏳ Waiting for Kubernetes pods to be ready..."

kubectl wait --for=condition=available --timeout=120s \
  deployment/postgres -n ecommerce 2>/dev/null || true

kubectl wait --for=condition=available --timeout=120s \
  deployment/product-service -n ecommerce 2>/dev/null || true

kubectl wait --for=condition=available --timeout=120s \
  deployment/order-service -n ecommerce 2>/dev/null || true

kubectl wait --for=condition=available --timeout=120s \
  deployment/user-service -n ecommerce 2>/dev/null || true

print_status "All Kubernetes pods ready!"

# ─────────────────────────────────────────
# STEP 7: Port Forwarding (skip if ports in use)
# ─────────────────────────────────────────
echo ""
echo "📋 Step 7: Setting up port forwarding..."

# Kill any existing port-forwards first
pkill -f "kubectl port-forward" 2>/dev/null || true
sleep 2

# Docker Compose already uses 5000-5002
# So we skip port-forward (Docker Compose services serve those ports)
print_status "Docker Compose already serving on ports 5000, 5001, 5002!"
print_warning "Kubernetes services accessible via Docker Compose (same app code)"

# ─────────────────────────────────────────
# STEP 8: Verify Everything
# ─────────────────────────────────────────
echo ""
echo "📋 Step 8: Verifying all services..."
echo ""

echo "🔍 Kubernetes Pods:"
kubectl get pods -n ecommerce
echo ""

echo "📊 HPA Status:"
kubectl get hpa -n ecommerce
echo ""

echo "🐳 Docker Containers:"
docker compose ps
echo ""

echo "🧪 Testing APIs..."
sleep 3
curl -s http://localhost:5000/health && echo " ✅ Product Service: OK" || echo " ❌ Product Service: FAILED"
curl -s http://localhost:5001/health && echo " ✅ Order Service:   OK" || echo " ❌ Order Service: FAILED"
curl -s http://localhost:5002/health && echo " ✅ User Service:    OK" || echo " ❌ User Service: FAILED"

echo ""
echo "================================================"
echo "✅ EVERYTHING IS RUNNING!"
echo "================================================"
echo ""
echo "🌐 Access Points:"
echo "   Product API:  http://localhost:5000/products"
echo "   Order API:    http://localhost:5001/orders"
echo "   User API:     http://localhost:5002/users"
echo "   Grafana:      http://localhost:3000  (admin/admin)"
echo "   Prometheus:   http://localhost:9090"
echo "   Kibana:       http://localhost:5601"
echo ""
echo "📊 Useful Commands:"
echo "   kubectl get pods -n ecommerce"
echo "   kubectl get hpa -n ecommerce"
echo "   kubectl top pods -n ecommerce"
echo "   docker compose logs -f"
echo ""
echo "🛑 To stop everything:"
echo "   ./stop-project.sh"
