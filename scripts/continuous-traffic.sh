#!/bin/bash

echo "🔥 Generating continuous traffic..."
echo "Press Ctrl+C to stop"

while true; do
    # Product service calls
    curl -s http://localhost:5000/products > /dev/null &
    curl -s http://localhost:5000/products/1 > /dev/null &
    curl -s http://localhost:5000/products/2 > /dev/null &
    curl -s http://localhost:5000/health > /dev/null &
    
    # Order service calls
    curl -s http://localhost:5001/orders > /dev/null &
    curl -s http://localhost:5001/orders/1 > /dev/null &
    curl -s http://localhost:5001/health > /dev/null &
    
    # User service calls
    curl -s http://localhost:5002/users > /dev/null &
    curl -s http://localhost:5002/users/1 > /dev/null &
    curl -s http://localhost:5002/health > /dev/null &
    
    # Random delays to simulate real traffic
    sleep $(awk -v min=0.1 -v max=0.5 'BEGIN{srand(); print min+rand()*(max-min)}')
done
