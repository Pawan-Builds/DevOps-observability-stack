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

# Prometheus metrics
metrics = PrometheusMetrics(app)
metrics.info('product_service_info', 'Product Service Info', version='1.0.0')

# Custom metrics
by_path_counter = metrics.counter(
    'by_path_counter', 'Request count by request paths',
    labels={'path': lambda: request.path}
)

# Logging configuration
logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","service":"product-service","level":"%(levelname)s","message":"%(message)s"}',
    handlers=[
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Database configuration
DB_CONFIG = {
    'host': os.getenv('DB_HOST', 'postgres'),
    'database': os.getenv('DB_NAME', 'ecommerce'),
    'user': os.getenv('DB_USER', 'admin'),
    'password': os.getenv('DB_PASSWORD', 'password'),
    'port': os.getenv('DB_PORT', '5432')
}

def get_db_connection():
    """Get database connection with retry logic"""
    max_retries = 5
    retry_delay = 2
    
    for attempt in range(max_retries):
        try:
            conn = psycopg2.connect(**DB_CONFIG, cursor_factory=RealDictCursor)
            logger.info("Database connection established")
            return conn
        except psycopg2.OperationalError as e:
            if attempt < max_retries - 1:
                logger.warning(f"Database connection attempt {attempt + 1} failed, retrying in {retry_delay}s...")
                time.sleep(retry_delay)
            else:
                logger.error(f"Failed to connect to database after {max_retries} attempts: {str(e)}")
                raise

@app.route('/health')
def health():
    """Health check endpoint"""
    try:
        conn = get_db_connection()
        conn.close()
        return jsonify({
            "status": "healthy",
            "service": "product-service",
            "timestamp": datetime.utcnow().isoformat()
        }), 200
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return jsonify({
            "status": "unhealthy",
            "service": "product-service",
            "error": str(e)
        }), 503

@app.route('/products', methods=['GET'])
@by_path_counter
def get_products():
    """Get all products"""
    logger.info("Fetching all products")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM products ORDER BY id')
        products = cursor.fetchall()
        cursor.close()
        conn.close()
        
        logger.info(f"Successfully fetched {len(products)} products")
        return jsonify({
            "products": products,
            "count": len(products)
        }), 200
    except Exception as e:
        logger.error(f"Error fetching products: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<int:product_id>', methods=['GET'])
@by_path_counter
def get_product(product_id):
    """Get product by ID"""
    logger.info(f"Fetching product {product_id}")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM products WHERE id = %s', (product_id,))
        product = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if product:
            logger.info(f"Product {product_id} found")
            return jsonify({"product": product}), 200
        else:
            logger.warning(f"Product {product_id} not found")
            return jsonify({"error": "Product not found"}), 404
    except Exception as e:
        logger.error(f"Error fetching product {product_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/products', methods=['POST'])
@by_path_counter
def create_product():
    """Create a new product"""
    data = request.get_json()
    logger.info(f"Creating new product: {data}")
    
    required_fields = ['name', 'price', 'stock']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO products (name, price, stock) VALUES (%s, %s, %s) RETURNING *',
            (data['name'], data['price'], data['stock'])
        )
        product = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"Product created successfully: {product}")
        return jsonify({
            "message": "Product created",
            "product": product
        }), 201
    except Exception as e:
        logger.error(f"Error creating product: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<int:product_id>', methods=['PUT'])
@by_path_counter
def update_product(product_id):
    """Update product"""
    data = request.get_json()
    logger.info(f"Updating product {product_id}: {data}")
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        # Build dynamic update query
        updates = []
        values = []
        for field in ['name', 'price', 'stock']:
            if field in data:
                updates.append(f"{field} = %s")
                values.append(data[field])
        
        if not updates:
            return jsonify({"error": "No fields to update"}), 400
        
        values.append(product_id)
        query = f"UPDATE products SET {', '.join(updates)} WHERE id = %s RETURNING *"
        
        cursor.execute(query, values)
        product = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if product:
            logger.info(f"Product {product_id} updated successfully")
            return jsonify({
                "message": "Product updated",
                "product": product
            }), 200
        else:
            return jsonify({"error": "Product not found"}), 404
    except Exception as e:
        logger.error(f"Error updating product {product_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<int:product_id>', methods=['DELETE'])
@by_path_counter
def delete_product(product_id):
    """Delete product"""
    logger.info(f"Deleting product {product_id}")
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('DELETE FROM products WHERE id = %s RETURNING id', (product_id,))
        deleted = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if deleted:
            logger.info(f"Product {product_id} deleted successfully")
            return jsonify({"message": "Product deleted"}), 200
        else:
            return jsonify({"error": "Product not found"}), 404
    except Exception as e:
        logger.error(f"Error deleting product {product_id}: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting Product Service on port 5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
