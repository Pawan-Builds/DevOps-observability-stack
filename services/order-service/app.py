from flask import Flask, jsonify, request
from prometheus_flask_exporter import PrometheusMetrics
from flask_cors import CORS
import logging
import psycopg2
from psycopg2.extras import RealDictCursor
import os
import sys
import time
from datetime import datetime

app = Flask(__name__)
CORS(app)

metrics = PrometheusMetrics(app)
metrics.info('order_service_info', 'Order Service Info', version='1.0.0')

logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","service":"order-service","level":"%(levelname)s","message":"%(message)s"}',
    handlers=[logging.StreamHandler(sys.stdout)]
)
logger = logging.getLogger(__name__)

DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres'),
    'database': os.getenv('DB_NAME', 'ecommerce'),
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'port': os.getenv('DB_PORT', '5432')
}

def get_db_connection():
    max_retries = 5
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            conn = psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)
            return conn
        except psycopg2.OperationalError as e:
            if attempt < max_retries - 1:
                logger.warning(f"Database connection attempt {attempt + 1} failed, retrying...")
                time.sleep(retry_delay)
            else:
                logger.error(f"Failed to connect to database: {str(e)}")
                raise

@app.route('/health')
def health():
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({"status": "healthy", "service": "order-service"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 503

@app.route('/orders', methods=['GET'])
def get_orders():
    logger.info("Fetching all orders")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT o.*, u.username, p.name as product_name 
            FROM orders o
            JOIN users u ON o.user_id = u.id
            JOIN products p ON o.product_id = p.id
            ORDER BY o.created_at DESC
        ''')
        orders = cursor.fetchall()
        cursor.close()
        conn.close()
        
        logger.info(f"Successfully fetched {len(orders)} orders")
        return jsonify({"orders": orders, "count": len(orders)}), 200
    except Exception as e:
        logger.error(f"Error fetching orders: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    logger.info(f"Fetching order {order_id}")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            SELECT o.*, u.username, p.name as product_name 
            FROM orders o
            JOIN users u ON o.user_id = u.id
            JOIN products p ON o.product_id = p.id
            WHERE o.id = %s
        ''', (order_id,))
        order = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if order:
            return jsonify({"order": order}), 200
        else:
            return jsonify({"error": "Order not found"}), 404
    except Exception as e:
        logger.error(f"Error fetching order: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders', methods=['POST'])
def create_order():
    data = request.get_json()
    logger.info(f"Creating new order: {data}")
    
    required_fields = ['user_id', 'product_id', 'quantity']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Get product price
        cursor.execute('SELECT price, stock FROM products WHERE id = %s', (data['product_id'],))
        product = cursor.fetchone()
        
        if not product:
            return jsonify({"error": "Product not found"}), 404
        
        if product['stock'] < data['quantity']:
            return jsonify({"error": "Insufficient stock"}), 400
        
        total_price = product['price'] * data['quantity']
        
        # Create order
        cursor.execute('''
            INSERT INTO orders (user_id, product_id, quantity, total_price, status) 
            VALUES (%s, %s, %s, %s, %s) RETURNING *
        ''', (data['user_id'], data['product_id'], data['quantity'], total_price, 'pending'))
        
        order = cursor.fetchone()
        
        # Update product stock
        cursor.execute(
            'UPDATE products SET stock = stock - %s WHERE id = %s',
            (data['quantity'], data['product_id'])
        )
        
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Order created successfully: {order}")
        return jsonify({"message": "Order created", "order": order}), 201
    except Exception as e:
        logger.error(f"Error creating order: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders/<int:order_id>/status', methods=['PUT'])
def update_order_status(order_id):
    data = request.get_json()
    
    if 'status' not in data:
        return jsonify({"error": "Status field required"}), 400
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            'UPDATE orders SET status = %s WHERE id = %s RETURNING *',
            (data['status'], order_id)
        )
        order = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if order:
            logger.info(f"Order {order_id} status updated to {data['status']}")
            return jsonify({"message": "Order status updated", "order": order}), 200
        else:
            return jsonify({"error": "Order not found"}), 404
    except Exception as e:
        logger.error(f"Error updating order status: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Order Service on port 5001")
    app.run(host='0.0.0.0', port=5001, debug=False)
