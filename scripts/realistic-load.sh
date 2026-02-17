#!/bin/bash

echo "🚀 Starting realistic load test..."
echo "This will run for 5 minutes"

END=$((SECONDS+300))  # 5 minutes

while [ $SECONDS -lt $END ]; do
    # Simulate 10 concurrent users
    for i in {1..10}; do
        (
            # Each user makes multiple requests
            curl -s http://localhost:5000/products > /dev/null
            curl -s http://localhost:5000/products/$((RANDOM % 5 + 1)) > /dev/null
            curl -s http://localhost:5001/orders > /dev/null
            curl -s http://localhost:5002/users > /dev/null
            
            # Occasionally create an order
            if [ $((RANDOM % 10)) -eq 0 ]; then
                curl -s -X POST http://localhost:5001/orders \
                  -H "Content-Type: application/json" \
                  -d '{"user_id":1,"product_id":'$((RANDOM % 5 + 1))',"quantity":1}' > /dev/null
            fi
        ) &
    done
    
    # Wait a bit before next batch
    sleep 1
done

wait
echo "✅ Load test complete! Check Grafana dashboard."
