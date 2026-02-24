.PHONY: help setup start stop restart status verify deploy-connectors clean logs mysql-setup mysql-shell kafka-shell workshop-start workshop-stop workshop-restart

# Paths
KAFKA_DOCKER_DIR := ../../../../Setup/Streaming/Kafka-Docker
CONNECTORS_DIR := ./connectors
SQL_DIR := ./sql

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
BLUE := \033[0;34m
NC := \033[0m

help:
	@echo "========================================"
	@echo "  Pentaho Kafka Workshop - Quick Commands"
	@echo "========================================"
	@echo ""
	@echo "$(BLUE)Workshop Setup:$(NC)"
	@echo "  make workshop-start   - Complete workshop startup (Kafka + connectors)"
	@echo "  make workshop-stop    - Stop entire workshop environment"
	@echo "  make workshop-restart - Restart entire workshop environment"
	@echo ""
	@echo "$(BLUE)Kafka Cluster:$(NC)"
	@echo "  make setup            - Generate Kafka cluster configuration"
	@echo "  make start            - Start Kafka cluster"
	@echo "  make stop             - Stop Kafka cluster"
	@echo "  make restart          - Restart Kafka cluster"
	@echo "  make status           - Show status of all containers"
	@echo "  make logs             - Show logs (tail -f)"
	@echo ""
	@echo "$(BLUE)Data & Connectors:$(NC)"
	@echo "  make deploy-connectors - Deploy workshop data generators"
	@echo "  make verify           - Verify workshop environment"
	@echo ""
	@echo "$(BLUE)Database (MySQL - Docker):$(NC)"
	@echo "  make mysql-setup      - Start MySQL and verify tables are ready"
	@echo "  make mysql-start      - Start MySQL Docker container"
	@echo "  make mysql-stop       - Stop MySQL container"
	@echo "  make mysql-shell      - Connect to MySQL shell"
	@echo "  make mysql-verify     - Verify MySQL tables and data"
	@echo "  make mysql-logs       - View MySQL logs"
	@echo "  make mysql-clean      - Remove MySQL container and data"
	@echo ""
	@echo "$(BLUE)Utilities:$(NC)"
	@echo "  make kafka-shell      - Open Kafka broker shell"
	@echo "  make topics           - List all Kafka topics"
	@echo "  make consumers        - List consumer groups"
	@echo "  make clean            - Clean up everything (stop + remove volumes)"
	@echo ""
	@echo "$(BLUE)Quick Links:$(NC)"
	@echo "  Control Center:  http://localhost:9021"
	@echo "  Kafka Connect:   http://localhost:8083"
	@echo "  Schema Registry: http://localhost:8081"
	@echo ""

# =====================================
# Workshop Quick Commands
# =====================================

workshop-start: setup start deploy-connectors mysql-start
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)  Workshop Environment Started!$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "Services available at:"
	@echo "  • Control Center:  http://localhost:9021"
	@echo "  • Kafka Connect:   http://localhost:8083"
	@echo "  • Schema Registry: http://localhost:8081"
	@echo "  • MySQL:           localhost:3306"
	@echo ""
	@echo "MySQL Connection:"
	@echo "  Database: kafka_warehouse"
	@echo "  User: kafka_user"
	@echo "  Password: kafka_password"
	@echo ""
	@echo "Next steps:"
	@echo "  1. Run 'make verify' to check environment"
	@echo "  2. Run 'make mysql-verify' to verify database"
	@echo "  3. Open Pentaho Spoon and start workshop"
	@echo ""

workshop-start-no-mysql: setup start deploy-connectors
	@echo ""
	@echo "$(GREEN)========================================$(NC)"
	@echo "$(GREEN)  Workshop Environment Started!$(NC)"
	@echo "$(GREEN)  (MySQL not started)$(NC)"
	@echo "$(GREEN)========================================$(NC)"
	@echo ""
	@echo "Services available at:"
	@echo "  • Control Center:  http://localhost:9021"
	@echo "  • Kafka Connect:   http://localhost:8083"
	@echo "  • Schema Registry: http://localhost:8081"
	@echo ""
	@echo "To start MySQL: make mysql-start"
	@echo ""

workshop-stop: stop mysql-stop
	@echo "$(YELLOW)Workshop environment stopped (Kafka + MySQL)$(NC)"

workshop-stop-kafka-only: stop
	@echo "$(YELLOW)Kafka stopped (MySQL still running)$(NC)"

workshop-restart: restart deploy-connectors
	@echo "$(GREEN)Workshop environment restarted$(NC)"

# =====================================
# Kafka Cluster Management
# =====================================

setup:
	@echo "$(BLUE)Generating Kafka cluster configuration...$(NC)"
	@if [ ! -f $(KAFKA_DOCKER_DIR)/docker-compose.yml ]; then \
		cd $(KAFKA_DOCKER_DIR) && $(MAKE) example-medium; \
	else \
		echo "$(YELLOW)Configuration already exists. Use 'make clean' to regenerate.$(NC)"; \
	fi
	@echo "$(GREEN)✓ Configuration ready$(NC)"

start:
	@echo "$(BLUE)Starting Kafka cluster...$(NC)"
	@if [ ! -f $(KAFKA_DOCKER_DIR)/docker-compose.yml ]; then \
		echo "$(RED)Error: docker-compose.yml not found. Run 'make setup' first.$(NC)"; \
		exit 1; \
	fi
	@cd $(KAFKA_DOCKER_DIR) && $(MAKE) docker-up
	@echo "$(YELLOW)Waiting for services to be ready (30 seconds)...$(NC)"
	@sleep 30
	@echo "$(GREEN)✓ Kafka cluster started$(NC)"

stop:
	@echo "$(YELLOW)Stopping Kafka cluster...$(NC)"
	@if [ -f $(KAFKA_DOCKER_DIR)/docker-compose.yml ]; then \
		cd $(KAFKA_DOCKER_DIR) && $(MAKE) docker-down; \
	else \
		echo "$(YELLOW)No docker-compose.yml found, nothing to stop$(NC)"; \
	fi
	@echo "$(GREEN)✓ Kafka cluster stopped$(NC)"

restart:
	@echo "$(BLUE)Restarting Kafka cluster...$(NC)"
	@cd $(KAFKA_DOCKER_DIR) && docker compose restart
	@echo "$(YELLOW)Waiting for services to be ready (20 seconds)...$(NC)"
	@sleep 20
	@echo "$(GREEN)✓ Kafka cluster restarted$(NC)"

status:
	@echo "$(BLUE)Kafka Cluster Status:$(NC)"
	@cd $(KAFKA_DOCKER_DIR) && docker compose ps

logs:
	@echo "$(BLUE)Streaming logs (Ctrl+C to exit)...$(NC)"
	@cd $(KAFKA_DOCKER_DIR) && $(MAKE) docker-logs

# =====================================
# Data Connectors
# =====================================

deploy-connectors:
	@echo "$(BLUE)Deploying workshop connectors...$(NC)"
	@if ! curl -s http://localhost:8083 > /dev/null 2>&1; then \
		echo "$(RED)Error: Kafka Connect is not running. Run 'make start' first.$(NC)"; \
		exit 1; \
	fi
	@cd $(CONNECTORS_DIR) && chmod +x deploy-connectors.sh && ./deploy-connectors.sh
	@echo "$(GREEN)✓ Connectors deployed$(NC)"
	@echo ""
	@echo "Verify connectors with:"
	@echo "  curl http://localhost:8083/connectors | jq"

verify:
	@echo "$(BLUE)Verifying workshop environment...$(NC)"
	@chmod +x scripts/verify-workshop-environment.sh
	@./scripts/verify-workshop-environment.sh

# =====================================
# MySQL Database (Docker)
# =====================================

mysql-setup: mysql-start mysql-verify
	@echo "$(GREEN)✓ MySQL setup complete$(NC)"

mysql-start:
	@echo "$(BLUE)Starting MySQL Docker container...$(NC)"
	@docker compose -f docker-compose-mysql.yml up -d
	@echo "$(YELLOW)Waiting for MySQL to be ready (15 seconds)...$(NC)"
	@sleep 15
	@echo "$(GREEN)✓ MySQL container started$(NC)"
	@echo ""
	@echo "Connection details:"
	@echo "  Host: localhost"
	@echo "  Port: 3306"
	@echo "  Database: kafka_warehouse"
	@echo "  User: kafka_user"
	@echo "  Password: kafka_password (default)"
	@echo ""
	@echo "Connect with: make mysql-shell"

mysql-stop:
	@echo "$(YELLOW)Stopping MySQL container...$(NC)"
	@docker compose -f docker-compose-mysql.yml down
	@echo "$(GREEN)✓ MySQL container stopped$(NC)"

mysql-restart:
	@echo "$(BLUE)Restarting MySQL container...$(NC)"
	@docker compose -f docker-compose-mysql.yml restart
	@sleep 10
	@echo "$(GREEN)✓ MySQL container restarted$(NC)"

mysql-logs:
	@echo "$(BLUE)MySQL logs (Ctrl+C to exit)...$(NC)"
	@docker compose -f docker-compose-mysql.yml logs -f

mysql-shell:
	@echo "$(BLUE)Connecting to MySQL shell...$(NC)"
	@docker exec -it kafka-workshop-mysql mysql -u kafka_user -pkafka_password kafka_warehouse

mysql-shell-root:
	@echo "$(BLUE)Connecting to MySQL as root...$(NC)"
	@docker exec -it kafka-workshop-mysql mysql -u root -prootpassword

mysql-verify:
	@echo "$(BLUE)Verifying MySQL setup...$(NC)"
	@echo ""
	@echo "$(YELLOW)Container status:$(NC)"
	@docker compose -f docker-compose-mysql.yml ps
	@echo ""
	@echo "$(YELLOW)Tables in kafka_warehouse:$(NC)"
	@docker exec kafka-workshop-mysql mysql -u kafka_user -pkafka_password kafka_warehouse -e "SHOW TABLES;"
	@echo ""
	@echo "$(YELLOW)Table statistics:$(NC)"
	@docker exec kafka-workshop-mysql mysql -u kafka_user -pkafka_password kafka_warehouse -e "SELECT table_name, table_rows, ROUND(data_length / 1024 / 1024, 2) as data_mb FROM information_schema.tables WHERE table_schema = 'kafka_warehouse' ORDER BY table_name;"

mysql-clean:
	@echo "$(YELLOW)Removing MySQL container and data...$(NC)"
	@docker compose -f docker-compose-mysql.yml down -v
	@echo "$(GREEN)✓ MySQL container and data removed$(NC)"

# Legacy support for non-Docker MySQL
mysql-setup-local:
	@echo "$(BLUE)Setting up local MySQL database...$(NC)"
	@if ! command -v mysql > /dev/null 2>&1; then \
		echo "$(RED)Error: MySQL client not found. Use 'make mysql-start' for Docker instead.$(NC)"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Please enter MySQL root password when prompted$(NC)"
	@mysql -u root -p < $(SQL_DIR)/01-create-database-mysql.sql
	@echo "$(GREEN)✓ MySQL database setup complete$(NC)"

# =====================================
# Kafka Utilities
# =====================================

kafka-shell:
	@echo "$(BLUE)Opening Kafka broker shell...$(NC)"
	@cd $(KAFKA_DOCKER_DIR) && docker exec -it kafka-1 /bin/bash

topics:
	@echo "$(BLUE)Kafka Topics:$(NC)"
	@./scripts/kafka-topics.sh --bootstrap-server localhost:9092 --list

topics-detail:
	@echo "$(BLUE)Kafka Topics (detailed):$(NC)"
	@./scripts/kafka-topics.sh --bootstrap-server localhost:9092 --describe

consumers:
	@echo "$(BLUE)Kafka Consumer Groups:$(NC)"
	@./scripts/kafka-consumer-groups.sh --bootstrap-server localhost:9092 --list

consume-users:
	@echo "$(BLUE)Consuming from pdi-users topic (Ctrl+C to exit)...$(NC)"
	@./scripts/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic pdi-users --from-beginning --max-messages 10

consume-trades:
	@echo "$(BLUE)Consuming from pdi-stocktrades topic (Ctrl+C to exit)...$(NC)"
	@./scripts/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic pdi-stocktrades --from-beginning --max-messages 10

# =====================================
# Cleanup
# =====================================

clean:
	@echo "$(YELLOW)Cleaning up workshop environment...$(NC)"
	@echo "This will:"
	@echo "  - Stop all containers"
	@echo "  - Remove all volumes (data will be lost)"
	@echo "  - Remove generated configs"
	@echo ""
	@read -p "Are you sure? (yes/no): " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		cd $(KAFKA_DOCKER_DIR) && $(MAKE) docker-down || true; \
		cd $(KAFKA_DOCKER_DIR) && docker compose down -v || true; \
		cd $(KAFKA_DOCKER_DIR) && $(MAKE) clean || true; \
		echo "$(GREEN)✓ Cleanup complete$(NC)"; \
	else \
		echo "$(YELLOW)Cleanup cancelled$(NC)"; \
	fi

clean-force:
	@echo "$(RED)Forcing cleanup...$(NC)"
	@cd $(KAFKA_DOCKER_DIR) && $(MAKE) docker-down || true
	@cd $(KAFKA_DOCKER_DIR) && docker compose down -v || true
	@cd $(KAFKA_DOCKER_DIR) && $(MAKE) clean || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# =====================================
# Development & Testing
# =====================================

test-connection:
	@echo "$(BLUE)Testing Kafka connection...$(NC)"
	@echo -n "  Kafka Broker (9092): "
	@if nc -z localhost 9092 2>/dev/null; then \
		echo "$(GREEN)✓ OK$(NC)"; \
	else \
		echo "$(RED)✗ FAILED$(NC)"; \
	fi
	@echo -n "  Kafka Connect (8083): "
	@if curl -s http://localhost:8083 > /dev/null 2>&1; then \
		echo "$(GREEN)✓ OK$(NC)"; \
	else \
		echo "$(RED)✗ FAILED$(NC)"; \
	fi
	@echo -n "  Schema Registry (8081): "
	@if curl -s http://localhost:8081 > /dev/null 2>&1; then \
		echo "$(GREEN)✓ OK$(NC)"; \
	else \
		echo "$(RED)✗ FAILED$(NC)"; \
	fi
	@echo -n "  Control Center (9021): "
	@if curl -s http://localhost:9021 > /dev/null 2>&1; then \
		echo "$(GREEN)✓ OK$(NC)"; \
	else \
		echo "$(RED)✗ FAILED$(NC)"; \
	fi

connectors-status:
	@echo "$(BLUE)Connector Status:$(NC)"
	@curl -s http://localhost:8083/connectors | jq -r '.[]' | while read connector; do \
		status=$$(curl -s http://localhost:8083/connectors/$$connector/status | jq -r '.connector.state'); \
		if [ "$$status" = "RUNNING" ]; then \
			echo "  $(GREEN)✓$(NC) $$connector: $$status"; \
		else \
			echo "  $(RED)✗$(NC) $$connector: $$status"; \
		fi \
	done

# =====================================
# Monitoring
# =====================================

monitor:
	@echo "$(BLUE)Workshop Monitoring Dashboard$(NC)"
	@echo "========================================"
	@echo ""
	@echo "$(YELLOW)Containers:$(NC)"
	@cd $(KAFKA_DOCKER_DIR) && docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"
	@echo ""
	@echo "$(YELLOW)Connectors:$(NC)"
	@make -s connectors-status
	@echo ""
	@echo "$(YELLOW)Topics:$(NC)"
	@./scripts/kafka-topics.sh --bootstrap-server localhost:9092 --list | grep "^pdi-" || echo "  No workshop topics found"
	@echo ""
	@echo "Press Ctrl+C to exit. Run 'make verify' for detailed checks."

# =====================================
# Quick Examples
# =====================================

example-consume:
	@echo "$(BLUE)Example: Consuming messages from pdi-users topic$(NC)"
	@echo "Run this command:"
	@echo "  docker exec kafka-1 kafka-console-consumer \\"
	@echo "    --bootstrap-server localhost:9092 \\"
	@echo "    --topic pdi-users \\"
	@echo "    --from-beginning \\"
	@echo "    --max-messages 5"
	@echo ""

example-produce:
	@echo "$(BLUE)Example: Producing a test message$(NC)"
	@echo "Run this command:"
	@echo "  echo '{\"test\": \"message\"}' | docker exec -i kafka-1 kafka-console-producer \\"
	@echo "    --bootstrap-server localhost:9092 \\"
	@echo "    --topic test-topic"
	@echo ""
