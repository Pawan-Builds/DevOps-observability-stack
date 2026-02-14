#!/bin/bash

echo "Starting chaos engineering tests..."

# Kill random pods
echo "Test 1: Killing random pods..."
kubectl delete pod -n ecommerce -l app=product-service --force --grace-period=0 &
sleep 5

# Check if service recovered
kubectl wait --for=condition=ready pod -n ecommerce -l app=product-service --timeout=60s

# Network latency injection
echo "Test 2: Injecting network latency..."
cat <<EOF | kubectl apply -f -
apiVersion: chaos-mesh.org/v1alpha1
kind: NetworkChaos
metadata:
  name: network-delay
  namespace: ecommerce
spec:
  action: delay
  mode: one
  selector:
    namespaces:
      - ecommerce
    labelSelectors:
      app: product-service
  delay:
    latency: "100ms"
    correlation: "100"
    jitter: "0ms"
  duration: "2m"
EOF

sleep 120

# Cleanup
kubectl delete networkchaos network-delay -n ecommerce

echo "Chaos tests completed! Check monitoring dashboards."
