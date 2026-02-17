#!/bin/bash
# ============================================
# Deploy Complete Ecommerce Stack to Kubernetes
# ============================================

set -e  # Exit on any error

echo "🚀 Deploying Ecommerce Microservices to Kubernetes"
echo "=================================================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl not found! Please install kubectl first."
    exit 1
fi

# Check cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster!"
    echo "Start minikube with: minikube start"
    exit 1
fi

echo ""
echo "📋 Step 1: Creating Namespace..."
kubectl apply -f k8s/namespace/namespace.yaml
print_status "Namespace 'ecommerce' created"

echo ""
echo "📋 Step 2: Creating ConfigMap..."
kubectl apply -f k8s/configmap/configmap.yaml
print_status "ConfigMap applied"

echo ""
echo "📋 Step 3: Creating Secrets..."
kubectl apply -f k8s/secrets/secrets.yaml
print_status "Secrets applied"

echo ""
echo "📋 Step 4: Deploying Database..."
kubectl apply -f k8s/deployments/postgres.yaml
print_status "PostgreSQL deployed"

echo ""
echo "⏳ Waiting for database to be ready..."
kubectl wait --for=condition=available --timeout=120s \
    deployment/postgres -n ecommerce
print_status "Database ready!"

echo ""
echo "📋 Step 5: Deploying Microservices..."
kubectl apply -f k8s/deployments/product-service.yaml
kubectl apply -f k8s/deployments/order-service.yaml
kubectl apply -f k8s/deployments/user-service.yaml
print_status "All microservices deployed"

echo ""
echo "📋 Step 6: Applying HPA (Autoscaling)..."
kubectl apply -f k8s/hpa/hpa.yaml
print_status "Horizontal Pod Autoscalers applied"

echo ""
echo "⏳ Waiting for services to be ready..."
kubectl wait --for=condition=available --timeout=120s \
    deployment/product-service -n ecommerce
kubectl wait --for=condition=available --timeout=120s \
    deployment/order-service -n ecommerce
kubectl wait --for=condition=available --timeout=120s \
    deployment/user-service -n ecommerce
print_status "All services ready!"

echo ""
echo "=================================================="
echo "✅ DEPLOYMENT COMPLETE!"
echo "=================================================="
echo ""
echo "📊 Current Status:"
kubectl get all -n ecommerce
echo ""
echo "🔍 HPA Status:"
kubectl get hpa -n ecommerce
echo ""
echo "📝 To access services:"
echo "   kubectl port-forward svc/product-service 5000:80 -n ecommerce"
echo "   kubectl port-forward svc/order-service 5001:80 -n ecommerce"
echo "   kubectl port-forward svc/user-service 5002:80 -n ecommerce"
echo ""
echo "📈 To view logs:"
echo "   kubectl logs -f deployment/product-service -n ecommerce"
echo ""
echo "🔄 To check pod status:"
echo "   kubectl get pods -n ecommerce -w"
