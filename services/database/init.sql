-- Create tables
CREATE TABLE IF NOT EXISTS products (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products(id) ON DELETE CASCADE,
    quantity INTEGER NOT NULL,
    total_price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO products (name, price, stock) VALUES
('Laptop', 999.99, 50),
('Wireless Mouse', 29.99, 200),
('Mechanical Keyboard', 79.99, 150),
('USB-C Hub', 49.99, 100),
('Webcam HD', 89.99, 75)
ON CONFLICT DO NOTHING;

INSERT INTO users (username, email) VALUES
('john_doe', 'john@example.com'),
('jane_smith', 'jane@example.com'),
('bob_wilson', 'bob@example.com')
ON CONFLICT DO NOTHING;

INSERT INTO orders (user_id, product_id, quantity, total_price, status) VALUES
(1, 1, 1, 999.99, 'completed'),
(2, 2, 2, 59.98, 'pending'),
(3, 3, 1, 79.99, 'shipped')
ON CONFLICT DO NOTHING;
