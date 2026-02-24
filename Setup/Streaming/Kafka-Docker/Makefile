.PHONY: help install test clean lint format docker-up docker-down docker-logs validate

# Default target
help:
	@echo "Kafka Docker Composer - Available Commands"
	@echo "=========================================="
	@echo "  make install      - Install dependencies"
	@echo "  make test         - Run unit tests"
	@echo "  make lint         - Run code linting (requires pylint)"
	@echo "  make format       - Format code with black (requires black)"
	@echo "  make clean        - Clean generated files and cache"
	@echo "  make docker-up    - Start Docker Compose cluster"
	@echo "  make docker-down  - Stop Docker Compose cluster"
	@echo "  make docker-logs  - Show Docker Compose logs"
	@echo "  make validate     - Validate generated docker-compose.yml"
	@echo "  make example-small   - Generate small cluster example"
	@echo "  make example-medium  - Generate medium cluster example"
	@echo "  make example-large   - Generate large cluster example"

install:
	@echo "Installing dependencies..."
	pip install -r requirements.txt

test:
	@echo "Running unit tests..."
	python3 -m unittest discover -s . -p "test_*.py" -v

lint:
	@echo "Running pylint..."
	@command -v pylint >/dev/null 2>&1 || { echo "pylint not installed. Install with: pip install pylint"; exit 1; }
	pylint kafka_docker_composer.py constants.py logger.py validator.py generators/*.py

format:
	@echo "Formatting code with black..."
	@command -v black >/dev/null 2>&1 || { echo "black not installed. Install with: pip install black"; exit 1; }
	black kafka_docker_composer.py constants.py logger.py validator.py generators/*.py test_*.py

clean:
	@echo "Cleaning generated files and cache..."
	rm -rf __pycache__ generators/__pycache__ docker-generator/__pycache__
	rm -f *.pyc generators/*.pyc docker-generator/*.pyc
	rm -f docker-compose.yml prometheus.yml
	rm -rf .pytest_cache .coverage htmlcov
	rm -rf build dist *.egg-info
	@echo "Clean complete!"

docker-up:
	@echo "Starting Docker Compose cluster..."
	@if [ ! -f docker-compose.yml ]; then \
		echo "Error: docker-compose.yml not found. Generate it first with:"; \
		echo "  python3 kafka_docker_composer.py [options]"; \
		exit 1; \
	fi
	docker compose up -d

docker-down:
	@echo "Stopping Docker Compose cluster..."
	@if [ ! -f docker-compose.yml ]; then \
		echo "Warning: docker-compose.yml not found"; \
	else \
		docker compose down; \
	fi

docker-logs:
	@echo "Showing Docker Compose logs..."
	docker compose logs -f

validate:
	@echo "Validating docker-compose.yml..."
	@if [ ! -f docker-compose.yml ]; then \
		echo "Error: docker-compose.yml not found"; \
		exit 1; \
	fi
	docker compose config --quiet && echo "✓ docker-compose.yml is valid"

example-small:
	@echo "Generating small cluster example (1 broker, dev/test)..."
	python3 kafka_docker_composer.py -b 1 -z 1 --resource-profile small

example-medium:
	@echo "Generating medium cluster example (3 brokers, KRaft, with monitoring)..."
	python3 kafka_docker_composer.py -b 3 -c 3 -p -s 1 -C 1 --resource-profile medium

example-large:
	@echo "Generating large cluster example (5 brokers, all services)..."
	python3 kafka_docker_composer.py -b 5 -c 3 -s 2 -C 2 -k 2 -p --control-center --resource-profile large

# Development targets
dev-install:
	@echo "Installing development dependencies..."
	pip install -r requirements.txt
	pip install pylint black pytest pytest-cov

coverage:
	@echo "Running tests with coverage..."
	pytest --cov=. --cov-report=html --cov-report=term

check: lint test
	@echo "All checks passed!"
