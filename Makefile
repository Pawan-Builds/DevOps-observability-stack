# Detect Docker Compose command
DOCKER_COMPOSE := $(shell if command -v docker-compose > /dev/null 2>&1; then echo "docker-compose"; else echo "docker compose"; fi)

.PHONY: help setup start stop restart logs clean test ps health

help:
	@echo "Available commands:"
	@echo "  make setup    - Initial setup and start all services"
	@echo "  make start    - Start all services"
	@echo "  make stop     - Stop all services"
	@echo "  make restart  - Restart all services"
	@echo "  make logs     - View logs"
	@echo "  make test     - Run load tests"
	@echo "  make clean    - Clean up everything"
	@echo "  make ps       - View running containers"
	@echo "  make health   - Check service health"

setup:
	@chmod +x scripts/*.sh
	@./scripts/setup-docker.sh

start:
	@$(DOCKER_COMPOSE) up -d

stop:
	@$(DOCKER_COMPOSE) down

restart:
	@$(DOCKER_COMPOSE) restart

logs:
	@$(DOCKER_COMPOSE) logs -f

test:
	@./scripts/load-test.sh

clean:
	@./scripts/cleanup.sh

ps:
	@docker ps

health:
	@echo "Checking service health..."
	@echo ""
	@echo "Product Service:"
	@curl -s http://localhost:5000/health | python3 -m json.tool || echo "Not available"
	@echo ""
	@echo "Order Service:"
	@curl -s http://localhost:5001/health | python3 -m json.tool || echo "Not available"
	@echo ""
	@echo "User Service:"
	@curl -s http://localhost:5002/health | python3 -m json.tool || echo "Not available"
