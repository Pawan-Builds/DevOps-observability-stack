#!/bin/bash

echo "🔥 Starting Load Test..."

# Check if curl and jq are installed
if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
    echo "❌ Please install curl and jq"
    exit 1
fi

BASE_URL="http://localhost"

# Function to test endpoint
test_endpoint() {
    local method=$1
    local endpoint=$2
    local data=$3
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -w "\n%{http_code}" "$BASE_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method -H "Content-Type: application/json" -d "$data" "$BASE_URL$endpoint")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo "✅ $method $endpoint - Status: $http_code"
    else
        echo "❌ $method $endpoint - Status: $http_code"
    fi
}

echo "Testing Product Service..."
for i in {1..10}; do
    test_endpoint "GET" ":5000/products"
    sleep 0.5
done

echo ""
echo "Testing Order Service..."
for i in {1..10}; do
    test_endpoint "GET" ":5001/orders"
    sleep 0.5
done

echo ""
echo "Testing User Service..."
for i in {1..10}; do
    test_endpoint "GET" ":5002/users"
    sleep 0.5
done

echo ""
echo "Creating test orders..."
for i in {1..5}; do
    test_endpoint "POST" ":5001/orders" '{"user_id":1,"product_id":1,"quantity":1}'
    sleep 1
done

echo ""
echo "✅ Load test complete! Check Grafana at http://localhost:3000"
