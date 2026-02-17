#!/bin/bash
# ============================================
# Stop Complete DevOps Observability Stack
# ============================================

echo "🛑 Stopping Complete DevOps Observability Stack..."
echo "================================================"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# ─────────────────────────────────────────
# STEP 1: Stop Port Forwarding
# ─────────────────────────────────────────
echo ""
echo "📋 Step 1: Stopping port forwards..."
pkill -f "kubectl port-forward" 2>/dev/null && \
  print_status "Port forwards stopped!" || \
  print_warning "No port forwards were running"

# ─────────────────────────────────────────
# STEP 2: Stop Docker Compose
# ─────────────────────────────────────────
echo ""
echo "📋 Step 2: Stopping Docker Compose stack..."
cd ~/devops-observability-stack
docker compose down
print_status "Docker Compose stack stopped!"

# ─────────────────────────────────────────
# STEP 3: Scale Down Kubernetes (optional - keeps cluster running)
# ─────────────────────────────────────────
echo ""
echo "📋 Step 3: Scaling down Kubernetes deployments..."
kubectl scale deployment product-service --replicas=0 -n ecommerce 2>/dev/null || true
kubectl scale deployment order-service --replicas=0 -n ecommerce 2>/dev/null || true
kubectl scale deployment user-service --replicas=0 -n ecommerce 2>/dev/null || true
kubectl scale deployment postgres --replicas=0 -n ecommerce 2>/dev/null || true
print_status "Kubernetes deployments scaled to 0!"

# ─────────────────────────────────────────
# STEP 4: Stop Minikube (optional)
# ─────────────────────────────────────────
echo ""
read -p "⚠️  Stop Minikube too? (y/N): " stop_minikube
if [[ "$stop_minikube" =~ ^[Yy]$ ]]; then
    minikube stop
    print_status "Minikube stopped!"
else
    print_warning "Minikube kept running (faster restart next time)"
fi

echo ""
echo "================================================"
echo "✅ EVERYTHING STOPPED!"
echo "================================================"
echo ""
echo "💡 To start again: ./start-project.sh"
