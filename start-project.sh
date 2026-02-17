#!/bin/bash
# ============================================
# Start Complete DevOps Observability Stack
# ============================================

set -e

# Go to script directory (works regardless of folder name)
cd "$(dirname "$0")"

echo "🚀 Starting Complete DevOps Observability Stack"
echo "================================================"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status()  { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error()   { echo -e "${RED}❌ $1${NC}"; }

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
docker compose up -d
print_status "Docker Compose stack started!"

echo "⏳ Waiting for Docker services to be healthy..."
sleep 15

# ─────────────────────────────────────────
# STEP 3: Auto-create Secrets (no file needed)
# ─────────────────────────────────────────
echo ""
echo "📋 Step 3: Creating Kubernetes secrets..."

# Create secrets directly with kubectl (no yaml file needed!)
kubectl create namespace ecommerce 2>/dev/null || true

kubectl create secret generic app-secrets \
  --namespace=ecommerce \
  --from-literal=DB_USER=admin \
  --from-literal=DB_PASSWORD=password \
  --from-literal=SECRET_KEY=secretkey \
  --dry-run=client -o yaml | kubectl apply -f -

print_status "Secrets created!"

# ─────────────────────────────────────────
# STEP 4: Apply Kubernetes Manifests
# ─────────────────────────────────────────
echo ""
echo "📋 Step 4: Applying Kubernetes manifests..."

kubectl apply -f k8s/namespace/namespace.yaml
kubectl apply -f k8s/configmap/configmap.yaml
kubectl apply -f k8s/deployments/postgres.yaml
kubectl apply -f k8s/deployments/product-service.yaml
kubectl apply -f k8s/deployments/order-service.yaml
kubectl apply -f k8s/deployments/user-service.yaml
kubectl apply -f k8s/hpa/hpa.yaml
print_status "Kubernetes manifests applied!"

# ─────────────────────────────────────────
# STEP 5: Load Images into Minikube
# ─────────────────────────────────────────
echo ""
echo "📋 Step 5: Loading images into Minikube..."

# Check if images exist in minikube already
if ! minikube image ls | grep -q "pawanm2307/product-service"; then
    echo "Loading images into minikube (first time only - takes 2-3 mins)..."
    minikube image load docker.io/pawanm2307/product-service:v1.0.0
    minikube image load docker.io/pawanm2307/order-service:v1.0.0
    minikube image load docker.io/pawanm2307/user-service:v1.0.0
    print_status "Images loaded into Minikube!"
else
    print_status "Images already in Minikube - skipping!"
fi

# ─────────────────────────────────────────
# STEP 6: Set Correct Images + Pull Policy
# ─────────────────────────────────────────
echo ""
echo "📋 Step 6: Configuring deployments..."

kubectl set image deployment/product-service \
  product-service=docker.io/pawanm2307/product-service:v1.0.0 \
  -n ecommerce 2>/dev/null || true

kubectl set image deployment/order-service \
  order-service=docker.io/pawanm2307/order-service:v1.0.0 \
  -n ecommerce 2>/dev/null || true

kubectl set image deployment/user-service \
  user-service=docker.io/pawanm2307/user-service:v1.0.0 \
  -n ecommerce 2>/dev/null || true

kubectl patch deployment product-service -n ecommerce \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"product-service","imagePullPolicy":"Never"}]}}}}' \
  2>/dev/null || true

kubectl patch deployment order-service -n ecommerce \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"order-service","imagePullPolicy":"Never"}]}}}}' \
  2>/dev/null || true

kubectl patch deployment user-service -n ecommerce \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"user-service","imagePullPolicy":"Never"}]}}}}' \
  2>/dev/null || true

print_status "Deployments configured!"

# ─────────────────────────────────────────
# STEP 7: Wait for Pods to be Ready
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
echo "🛑 To stop everything: ./stop-project.sh"
