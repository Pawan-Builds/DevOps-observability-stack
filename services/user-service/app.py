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
metrics.info('user_service_info', 'User Service Info', version='1.0.0')

logging.basicConfig(
    level=logging.INFO,
    format='{"timestamp":"%(asctime)s","service":"user-service","level":"%(levelname)s","message":"%(message)s"}',
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
        return jsonify({"status": "healthy", "service": "user-service"}), 200
    except Exception as e:
        return jsonify({"status": "unhealthy", "error": str(e)}), 503

@app.route('/users', methods=['GET'])
def get_users():
    logger.info("Fetching all users")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT id, username, email, created_at FROM users ORDER BY id')
        users = cursor.fetchall()
        cursor.close()
        conn.close()
        
        logger.info(f"Successfully fetched {len(users)} users")
        return jsonify({"users": users, "count": len(users)}), 200
    except Exception as e:
        logger.error(f"Error fetching users: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    logger.info(f"Fetching user {user_id}")
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT id, username, email, created_at FROM users WHERE id = %s', (user_id,))
        user = cursor.fetchone()
        cursor.close()
        conn.close()
        
        if user:
            return jsonify({"user": user}), 200
        else:
            return jsonify({"error": "User not found"}), 404
    except Exception as e:
        logger.error(f"Error fetching user: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/users', methods=['POST'])
def create_user():
    data = request.get_json()
    logger.info(f"Creating new user: {data.get('username')}")
    
    required_fields = ['username', 'email']
    if not all(field in data for field in required_fields):
        return jsonify({"error": "Missing required fields"}), 400
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO users (username, email) VALUES (%s, %s) RETURNING id, username, email, created_at',
            (data['username'], data['email'])
        )
        user = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        logger.info(f"User created successfully: {user}")
        return jsonify({"message": "User created", "user": user}), 201
    except psycopg2.IntegrityError as e:
        logger.error(f"User already exists: {str(e)}")
        return jsonify({"error": "Username or email already exists"}), 409
    except Exception as e:
        logger.error(f"Error creating user: {str(e)}")
        return jsonify({"error": str(e)}), 500

@app.route('/users/<int:user_id>', methods=['PUT'])
def update_user(user_id):
    data = request.get_json()
    logger.info(f"Updating user {user_id}")
    
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        
        updates = []
        values = []
        for field in ['username', 'email']:
            if field in data:
                updates.append(f"{field} = %s")
                values.append(data[field])
        
        if not updates:
            return jsonify({"error": "No fields to update"}), 400
        
        values.append(user_id)
        query = f"UPDATE users SET {', '.join(updates)} WHERE id = %s RETURNING id, username, email, created_at"
        
        cursor.execute(query, values)
        user = cursor.fetchone()
        conn.commit()
        cursor.close()
        conn.close()
        
        if user:
            logger.info(f"User {user_id} updated successfully")
            return jsonify({"message": "User updated", "user": user}), 200
        else:
            return jsonify({"error": "User not found"}), 404
    except Exception as e:
        logger.error(f"Error updating user: {str(e)}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    logger.info("Starting User Service on port 5002")
    app.run(host='0.0.0.0', port=5002, debug=False)
