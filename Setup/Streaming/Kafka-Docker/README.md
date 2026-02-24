# Kafka Docker Composer

A powerful Python tool to generate production-ready Apache Kafka clusters using Docker Compose. This tool provides comprehensive configuration validation, resource management, data persistence, and professional logging to help you quickly deploy Kafka clusters for development, testing, or production use.

## Table of Contents

- [Features](#features)
- [Workshops](#workshops)
- [Quick Start](#quick-start)
- [Installation](#installation)
- [Usage](#usage)
  - [Command-Line Options](#command-line-options)
  - [Examples](#examples)
- [Configuration](#configuration)
  - [Resource Profiles](#resource-profiles)
  - [Data Persistence](#data-persistence)
  - [Logging](#logging)
- [Accessing Services](#accessing-services)
  - [Web Interfaces](#web-interfaces)
  - [Kafka Brokers](#kafka-brokers)
  - [API Endpoints](#api-endpoints)
- [Common Operations](#common-operations)
  - [Topic Management](#topic-management)
  - [Producer and Consumer Examples](#producer-and-consumer-examples)
  - [Volume Management](#volume-management)
  - [Resource Monitoring](#resource-monitoring)
- [Architecture](#architecture)
- [Troubleshooting](#troubleshooting)
- [Advanced Topics](#advanced-topics)
- [Documentation](#documentation)

## Features

- **Flexible Deployment Modes**: Choose between ZooKeeper (legacy) or KRaft (modern) mode
- **Data Persistence**: Optional Docker volumes ensure data survives container restarts
- **Resource Management**: Predefined profiles (small/medium/large) with CPU and memory limits
- **Configuration Validation**: Pre-generation validation with helpful error messages and suggestions
- **Professional Logging**: Colored console output with optional file logging and multiple log levels
- **Complete Ecosystem**: Support for all Confluent Platform components:
  - Kafka Brokers and Controllers
  - ZooKeeper (legacy mode)
  - Schema Registry
  - Kafka Connect
  - ksqlDB
  - Confluent Control Center
  - Prometheus and Grafana monitoring
- **JMX Monitoring**: Built-in JMX exporters for Prometheus integration
- **Network Simulation**: Support for rack awareness and multi-datacenter simulation
- **Extensible**: Easy integration with additional services via docker-compose overlays

## Workshops

This project includes comprehensive hands-on workshops for learning Kafka-based streaming data integration:

### Pentaho Data Integration Kafka EE Plugin Workshop

**Location**: [Workshop/Pentaho-Kafka-EE/](Workshop/Pentaho-Kafka-EE/)

A complete workshop demonstrating the Pentaho PDI Kafka Enterprise Edition plugin using real streaming data sources.

**Features**:
- 6 hands-on scenarios (beginner to advanced)
- 15-minute quick start guide
- Complete configuration documentation
- Live data generators (users, stock trades, purchases, pageviews)
- Production-ready patterns and best practices

**Quick Start**:
```bash
# 1. Generate Kafka cluster (see Quick Start below)
# 2. Deploy data generators
cd Workshop/Pentaho-Kafka-EE/connectors
./deploy-connectors.sh

# 3. Follow workshop guide
cat Workshop/Pentaho-Kafka-EE/QUICK-START.md
```

**What You'll Learn**:
- Kafka Consumer and Producer step configuration
- Batch processing and offset management
- Multi-topic processing and stream enrichment
- Schema Registry integration (Avro)
- Security implementation (SSL/SASL)
- Performance tuning and monitoring

See [Workshop/README.md](Workshop/README.md) for complete details.

## Quick Start

### 1. Install Dependencies

```bash
# Option 1: Using pip with requirements.txt (recommended)
pip install -r requirements.txt

# Option 2: Using pip in virtual environment (best practice)
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Option 3: Using apt (Debian/Ubuntu)
sudo apt install python3-jinja2

# For development (includes testing and linting tools)
pip install -r requirements-dev.txt
```

### 2. Generate Cluster Configuration

**Development cluster (minimal):**
```bash
python3 kafka_docker_composer.py -b 1 -c 1 --resource-profile small
docker compose up -d
```

**Production cluster (recommended):**
```bash
python3 kafka_docker_composer.py \
  --brokers 3 \
  --controllers 3 \
  --schema-registries 1 \
  --connect 2 \
  --control-center \
  --prometheus \
  --persistent-volumes \
  --resource-profile medium \
  -v

docker compose up -d
```

### 3. Access Services

After containers start (wait 1-2 minutes for full initialization):

- **Control Center**: http://localhost:9021
- **Prometheus**: http://localhost:9090
- **Grafana**: http://localhost:3000
- **Schema Registry**: http://localhost:8081
- **Kafka Connect**: http://localhost:8083

## Installation

### Requirements

- **Python**: 3.7 or later
- **Docker**: 20.10 or later
- **Docker Compose**: 2.0 or later (or Docker with Compose plugin)
- **System Memory**: Minimum 4GB, recommended 8GB+ for full stack
- **Python Package**: jinja2

### Verify Installation

```bash
# Check Python version
python3 --version

# Check Docker
docker --version
docker compose version

# Check jinja2
python3 -c "import jinja2; print(jinja2.__version__)"
```

### Using the Makefile (Optional)

The project includes a `Makefile` with convenient shortcuts for common tasks:

```bash
# Show all available commands
make help

# Install dependencies
make install

# Run tests
make test

# Generate example clusters
make example-small    # 1 broker, small profile
make example-medium   # 3 brokers, KRaft mode
make example-large    # 5 brokers, all services

# Docker operations
make docker-up        # Start cluster
make docker-down      # Stop cluster
make docker-logs      # View logs
make validate         # Validate docker-compose.yml

# Development tasks
make clean            # Clean cache and generated files
make lint             # Run code linting
make format           # Format code with black
```

## Usage

### Command-Line Options

```bash
python3 kafka_docker_composer.py [OPTIONS]
```

#### Cluster Configuration

| Option | Description | Default |
|--------|-------------|---------|
| `-r, --release` | Confluent Platform version | 7.9.5 |
| `-b, --brokers` | Number of Kafka brokers | 1 |
| `-c, --controllers` | Number of KRaft controllers | 0 |
| `-z, --zookeepers` | Number of ZooKeeper nodes | 0 |
| `-s, --schema-registries` | Number of Schema Registry instances | 0 |
| `-C, --connect` | Number of Kafka Connect workers | 0 |
| `-K, --ksqldb-instances` | Number of ksqlDB servers | 0 |
| `--control-center` | Include Confluent Control Center | false |
| `--control-center-next-gen` | Include next-gen Control Center | false |
| `-p, --prometheus` | Include Prometheus and Grafana | false |
| `--uuid` | Cluster UUID | auto-generated |
| `--racks` | Number of racks for broker distribution | 1 |
| `--kafka-container` | Container image for Kafka | cp-server |

#### Data Persistence

| Option | Description | Default |
|--------|-------------|---------|
| `--persistent-volumes` | Enable persistent Docker volumes | false |
| `--volume-driver` | Docker volume driver | local |

#### Resource Management

| Option | Description | Default |
|--------|-------------|---------|
| `--resource-profile` | Resource profile: none/small/medium/large | none |
| `--custom-broker-memory` | Custom broker memory limit (e.g., 2g) | - |
| `--custom-broker-cpus` | Custom broker CPU limit (e.g., 1.0) | - |
| `--custom-broker-heap` | Custom broker heap size (e.g., 1g) | - |

#### Logging and Debugging

| Option | Description | Default |
|--------|-------------|---------|
| `-v, --verbose` | Enable DEBUG-level logging | false |
| `--log-file` | Write logs to specified file | - |
| `--no-color` | Disable colored console output | false |

#### Output

| Option | Description | Default |
|--------|-------------|---------|
| `--docker-compose-file` | Output filename | docker-compose.yaml |
| `--config` | Load configuration from properties file | - |

### Examples

#### Minimal Development Setup

Single broker and controller for local testing:

```bash
python3 kafka_docker_composer.py \
  --brokers 1 \
  --controllers 1 \
  --resource-profile small

docker compose up -d
```

#### ZooKeeper Mode (Legacy)

Traditional Kafka with ZooKeeper ensemble:

```bash
python3 kafka_docker_composer.py \
  --brokers 3 \
  --zookeepers 3 \
  --release 7.9.5

docker compose up -d
```

#### KRaft Mode (Recommended)

Modern Kafka without ZooKeeper:

```bash
python3 kafka_docker_composer.py \
  --brokers 3 \
  --controllers 3 \
  --persistent-volumes \
  --resource-profile medium

docker compose up -d
```

#### Full Production Stack

Complete ecosystem with monitoring and data services:

```bash
python3 kafka_docker_composer.py \
  --brokers 3 \
  --controllers 3 \
  --schema-registries 1 \
  --connect 2 \
  --ksqldb-instances 1 \
  --control-center \
  --prometheus \
  --persistent-volumes \
  --resource-profile large \
  --log-file setup.log \
  -v

docker compose up -d
```

#### Custom Resource Limits

Fine-tune resource allocation:

```bash
python3 kafka_docker_composer.py \
  --brokers 3 \
  --controllers 3 \
  --custom-broker-memory 3g \
  --custom-broker-cpus 1.5 \
  --custom-broker-heap 1536m \
  --persistent-volumes

docker compose up -d
```

## Configuration

### Resource Profiles

Choose a resource profile based on your use case:

| Profile | Broker Memory | Broker CPU | Broker Heap | Use Case |
|---------|---------------|------------|-------------|----------|
| **none** (default) | No limit | No limit | 1g | Local development, maximum flexibility |
| **small** | 512m | 0.5 | 256m | Testing, CI/CD, resource-constrained environments |
| **medium** | 2g | 1.0 | 1g | Small production, development with realistic load |
| **large** | 4g | 2.0 | 2g | Production workloads, high throughput |

All profiles also configure appropriate limits for:
- Controllers: 256-512MB memory
- ZooKeeper: 256-512MB memory
- Schema Registry: 256-512MB memory
- Kafka Connect: 512MB-1GB memory
- ksqlDB: 1-2GB memory
- Control Center: 2-4GB memory
- Prometheus: 512MB-1GB memory
- Grafana: 256MB memory

### Data Persistence

Enable `--persistent-volumes` to ensure data survives container restarts and updates.

**Volumes created:**

- **Kafka Brokers**: `kafka-{1,2,3,...}-data` and `kafka-{1,2,3,...}-logs`
- **Controllers**: `controller-{1,2,3,...}-data`
- **ZooKeeper**: `zookeeper-{1,2,3,...}-data` and `zookeeper-{1,2,3,...}-logs`
- **Prometheus**: `prometheus-data`
- **Grafana**: `grafana-data`

**Example:**

```bash
# Enable persistence
python3 kafka_docker_composer.py -b 3 -c 3 --persistent-volumes

# Start cluster
docker compose up -d

# Stop cluster (data is preserved)
docker compose down

# Restart cluster (data is restored)
docker compose up -d

# Remove cluster AND data
docker compose down -v
```

### Logging

The tool provides professional logging with multiple output options:

**Console Output:**
```bash
# Standard output (INFO level)
python3 kafka_docker_composer.py -b 3 -c 3

# Verbose output (DEBUG level)
python3 kafka_docker_composer.py -b 3 -c 3 -v

# No colored output (for CI/CD)
python3 kafka_docker_composer.py -b 3 -c 3 --no-color
```

**File Logging:**
```bash
# Log to file (always DEBUG level)
python3 kafka_docker_composer.py -b 3 -c 3 --log-file setup.log

# Both console and file
python3 kafka_docker_composer.py -b 3 -c 3 -v --log-file setup.log
```

**Log Levels:**
- **DEBUG** (`-v`): Detailed generation steps, validation checks, configuration details
- **INFO** (default): Configuration summary, important messages, warnings
- **WARNING**: Configuration warnings, recommendations, potential issues
- **ERROR**: Fatal errors that prevent generation

### Configuration Validation

The tool automatically validates your configuration before generating docker-compose.yml:

**Errors** (prevent generation):
- Invalid parameter values (e.g., `brokers < 1`)
- Impossible configurations (e.g., even controller count in quorum)
- Missing prerequisites (Docker not found)

**Warnings** (inform but don't prevent):
- Suboptimal configurations (e.g., single broker cluster)
- High resource usage (e.g., estimated memory > 8GB)
- Best practice violations (e.g., 2 controllers can't form quorum)

**Example validation output:**

```
INFO: Validating configuration...
WARNING: Single broker configuration - no fault tolerance
  💡 Consider using at least 3 brokers for production
WARNING: 2 controllers cannot form a quorum if one fails
  💡 Use odd numbers (1, 3, 5) for controller count
WARNING: Estimated memory usage: ~10240MB
  💡 Ensure Docker has sufficient memory allocated
INFO: Validation complete. Generating docker-compose.yml...
```

## Accessing Services

### Web Interfaces

After starting your cluster, web services are available at:

| Service | URL | Description |
|---------|-----|-------------|
| **Control Center** | http://localhost:9021 | Web UI for cluster management, topic browser, monitoring |
| **Prometheus** | http://localhost:9090 | Metrics collection and query interface |
| **Grafana** | http://localhost:3000 | Visualization dashboards (default: admin/admin) |

**Note**: Control Center may take 1-2 minutes to fully initialize after container startup.

### Kafka Brokers

**External Access (from host machine):**

Bootstrap servers: `localhost:9091,localhost:9092,localhost:9093`

**Internal Access (from Docker containers):**

Bootstrap servers: `kafka-1:19094,kafka-2:19095,kafka-3:19096`

### API Endpoints

| Service | URL | Description |
|---------|-----|-------------|
| **Schema Registry** | http://localhost:8081 | REST API for schema management |
| **Kafka Connect** | http://localhost:8083 | REST API for connector management (first instance) |
| **Kafka Connect** | http://localhost:8084 | REST API for connector management (second instance) |
| **ksqlDB** | http://localhost:8088 | REST API for stream processing |

## Common Operations

### Topic Management

#### Create a Topic

```bash
docker exec -it kafka-1 kafka-topics \
  --bootstrap-server localhost:9091 \
  --create \
  --topic my-topic \
  --partitions 3 \
  --replication-factor 3
```

#### List Topics

```bash
docker exec -it kafka-1 kafka-topics \
  --bootstrap-server localhost:9091 \
  --list
```

#### Describe a Topic

```bash
docker exec -it kafka-1 kafka-topics \
  --bootstrap-server localhost:9091 \
  --describe \
  --topic my-topic
```

#### Delete a Topic

```bash
docker exec -it kafka-1 kafka-topics \
  --bootstrap-server localhost:9091 \
  --delete \
  --topic my-topic
```

### Producer and Consumer Examples

#### Console Producer

```bash
docker exec -it kafka-1 kafka-console-producer \
  --bootstrap-server localhost:9091 \
  --topic test-topic
```

Type messages and press Enter. Use Ctrl+C to exit.

#### Console Consumer

```bash
docker exec -it kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9091 \
  --topic test-topic \
  --from-beginning
```

#### Python Producer Example

```python
from kafka import KafkaProducer

producer = KafkaProducer(
    bootstrap_servers=['localhost:9091', 'localhost:9092', 'localhost:9093']
)

producer.send('test-topic', b'Hello World')
producer.flush()
```

#### Python Consumer Example

```python
from kafka import KafkaConsumer

consumer = KafkaConsumer(
    'test-topic',
    bootstrap_servers=['localhost:9091', 'localhost:9092', 'localhost:9093'],
    auto_offset_reset='earliest',
    group_id='my-group'
)

for message in consumer:
    print(message.value)
```

### Volume Management

If you enabled `--persistent-volumes`, manage your data with these commands:

#### List Volumes

```bash
docker volume ls | grep kafka
```

#### Inspect Volume

```bash
docker volume inspect kafka-1-data
```

#### Backup Volume

```bash
# Backup broker data
docker run --rm \
  -v kafka-1-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/kafka-1-backup.tar.gz /data

# Backup Prometheus metrics
docker run --rm \
  -v prometheus-data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/prometheus-backup.tar.gz /data
```

#### Restore Volume

```bash
# Stop services first
docker compose stop

# Restore data
docker run --rm \
  -v kafka-1-data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/kafka-1-backup.tar.gz -C /

# Restart services
docker compose start
```

#### Remove Volumes

```bash
# Remove all volumes (⚠️ PERMANENT DATA LOSS)
docker compose down -v

# Remove specific volume
docker volume rm kafka-1-data
```

### Resource Monitoring

#### View Resource Usage

```bash
# All services
docker stats

# Specific service
docker stats kafka-1

# Resource usage summary
docker compose ps
```

#### Check Resource Limits

```bash
# Memory limits
docker inspect kafka-1 | grep -A 10 "Memory"

# CPU limits
docker inspect kafka-1 | grep -A 5 "NanoCpus"
```

#### View Logs

```bash
# All services (follow mode)
docker compose logs -f

# Specific service
docker compose logs -f kafka-1

# Last 100 lines
docker compose logs --tail=100 kafka-1

# Since timestamp
docker compose logs --since 10m kafka-1
```

#### Container Shell Access

```bash
# Interactive shell
docker exec -it kafka-1 bash

# Run single command
docker exec kafka-1 kafka-broker-api-versions \
  --bootstrap-server localhost:9091
```

### Cluster Operations

#### Stop Services

```bash
# Stop all services (preserves data if using volumes)
docker compose stop

# Stop specific service
docker compose stop kafka-1
```

#### Restart Services

```bash
# Restart all services
docker compose restart

# Restart specific service
docker compose restart kafka-1
```

#### Remove All Services

```bash
# Stop and remove containers (preserves volumes)
docker compose down

# Stop, remove containers AND volumes (⚠️ DATA LOSS)
docker compose down -v
```

## Architecture

### KRaft Mode (Recommended)

Modern Kafka architecture without ZooKeeper dependency:

```
┌─────────────────────────────────────────────────────────┐
│                    Kafka Cluster                        │
├─────────────────────────────────────────────────────────┤
│  Controllers (Metadata Quorum)                          │
│  ├─ controller-1  (Raft leader election)                │
│  ├─ controller-2  (Metadata replication)                │
│  └─ controller-3  (Fault tolerance)                     │
│                                                          │
│  Brokers (Data Storage & Serving)                       │
│  ├─ kafka-1  (Partitions, replication)                  │
│  ├─ kafka-2  (Producer/consumer handling)               │
│  └─ kafka-3  (Cluster coordination)                     │
└─────────────────────────────────────────────────────────┘
```

**Advantages**:
- Simplified operations (no ZooKeeper to manage)
- Faster metadata operations
- Better scalability
- Single security model
- Future-proof (ZooKeeper mode deprecated)

### ZooKeeper Mode (Legacy)

Traditional Kafka architecture with ZooKeeper:

```
┌─────────────────────────────────────────────────────────┐
│  ZooKeeper Ensemble (Coordination)                      │
│  ├─ zookeeper-1  (Leader election)                      │
│  ├─ zookeeper-2  (Cluster state)                        │
│  └─ zookeeper-3  (Configuration)                        │
└─────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────┐
│  Kafka Brokers                                          │
│  ├─ kafka-1  (Data storage & serving)                   │
│  ├─ kafka-2  (Replication)                              │
│  └─ kafka-3  (Producer/consumer handling)               │
└─────────────────────────────────────────────────────────┘
```

**When to use**:
- Compatibility with older Kafka clients
- Migration from existing ZooKeeper-based deployments
- Specific tools that don't yet support KRaft

### Port Allocation

**Kafka Brokers (External):**
- kafka-1: localhost:9091
- kafka-2: localhost:9092
- kafka-3: localhost:9093

**Kafka Brokers (Internal):**
- kafka-1: kafka-1:19094
- kafka-2: kafka-2:19095
- kafka-3: kafka-3:19096

**Controllers:**
- controller-1: localhost:19091
- controller-2: localhost:19092
- controller-3: localhost:19093

**JMX Ports (Brokers):**
- kafka-1: localhost:10001
- kafka-2: localhost:10002
- kafka-3: localhost:10003

**Prometheus Exporters (Brokers):**
- kafka-1: localhost:10101
- kafka-2: localhost:10102
- kafka-3: localhost:10103

**Standard Services:**
- Control Center: localhost:9021
- Prometheus: localhost:9090
- Grafana: localhost:3000
- Schema Registry: localhost:8081
- Kafka Connect: localhost:8083, 8084, ...

## Troubleshooting

### Configuration Validation Errors

**Error: At least 1 broker is required**

Solution: Use `-b` or `--brokers` with a value >= 1

```bash
python3 kafka_docker_composer.py -b 3 -c 3
```

**Error: KRaft mode requires at least 1 controller**

Solution: Use `-c` or `--controllers` with a value >= 1 for KRaft mode

```bash
python3 kafka_docker_composer.py -b 3 -c 3
```

### Container Startup Issues

**Control Center not loading:**

- Wait 2-3 minutes after startup (it's slow to initialize)
- Check logs: `docker compose logs control-center`
- Verify all brokers are healthy: `docker compose ps`

**Cannot connect to brokers:**

- Verify containers are running: `docker compose ps`
- Check broker logs: `docker compose logs kafka-1`
- Test connectivity: `telnet localhost 9091`
- Ensure ports aren't blocked by firewall

**Out of memory errors:**

- Check available system memory: `free -h`
- Use smaller resource profile: `--resource-profile small`
- Reduce number of services
- Increase Docker memory limit (Docker Desktop → Settings → Resources)

**Port conflicts:**

- Check for services using required ports: `netstat -tuln | grep 9091`
- Stop conflicting services
- Modify port mappings in generated docker-compose.yml

### Performance Issues

**Slow message processing:**

- Increase broker memory: `--custom-broker-memory 4g`
- Increase heap size: `--custom-broker-heap 2g`
- Add more brokers: `-b 5`
- Check resource usage: `docker stats`

**High CPU usage:**

- Review topic partition count (too many partitions can cause overhead)
- Increase replication.fetch.wait.max.ms
- Consider using compression
- Check for hot partitions

### Data Issues

**Data lost after restart:**

- Enable persistent volumes: `--persistent-volumes`
- Verify volumes exist: `docker volume ls`
- Don't use `docker compose down -v` (removes volumes)

**Disk space issues:**

- Check volume usage: `docker system df`
- Configure log retention policies
- Clean up old Docker resources: `docker system prune`

### Common Questions

**Q: How do I upgrade Confluent Platform version?**

A: Regenerate configuration with new version and restart:
```bash
python3 kafka_docker_composer.py -b 3 -c 3 -r 7.10.0 --persistent-volumes
docker compose down
docker compose up -d
```

**Q: Can I add brokers to a running cluster?**

A: Yes, regenerate with more brokers and use `docker compose up -d`:
```bash
python3 kafka_docker_composer.py -b 5 -c 3 --persistent-volumes
docker compose up -d
```

**Q: How do I reset the cluster completely?**

A: Remove all containers and volumes:
```bash
docker compose down -v
docker compose up -d
```

## Advanced Topics

### Kafka Connect Connectors

The `volumes/connector-plugin-jars` directory contains connector plugins that are automatically loaded by Kafka Connect workers.

**Add a connector:**

1. Download connector ZIP from Confluent Hub or vendor
2. Extract to `volumes/connector-plugin-jars/connector-name/`
3. Restart Connect workers: `docker compose restart connect-1 connect-2`

**List available connectors:**

```bash
curl http://localhost:8083/connector-plugins | jq
```

**Deploy a connector:**

```bash
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json
```

### Schema Registry

**List schemas:**

```bash
curl http://localhost:8081/subjects
```

**Register a schema:**

```bash
curl -X POST http://localhost:8081/subjects/test-value/versions \
  -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  -d '{"schema": "{\"type\":\"string\"}"}'
```

**Get schema:**

```bash
curl http://localhost:8081/subjects/test-value/versions/latest
```

### Docker Compose Overlays

Extend your cluster with additional services using Docker Compose overlays:

**Development Override:**

The project includes `docker-compose.dev.yml` for development-specific settings:

```bash
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d
```

**Example: Add PostgreSQL**

```bash
docker compose -f docker-compose.yaml -f postgres.yaml up -d
```

Create `postgres.yaml`:

```yaml
version: '3.8'
services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: postgres
    ports:
      - "5432:5432"
    networks:
      - kafka-network

networks:
  kafka-network:
    external: true
```

### Deployment to Production

**Copy to Home Directory:**

A convenience script is provided to copy the entire setup with proper permissions:

```bash
# Run the copy script
./copy_to_home.sh

# This will copy everything from:
#   ~/Workshop--Data-Integration/Setup/Streaming/Kafka-Docker
# to:
#   ~/Kafka-Docker
```

The script:
- Preserves all file permissions and timestamps
- Copies hidden files (.env, .git, .gitignore)
- Prompts before overwriting existing directories
- Verifies the copy was successful
- Shows which files retained executable permissions

### Custom Configuration

Override Kafka broker settings by editing the generated `docker-compose.yaml` or creating a configuration file:

**Example configuration file (`kafka.properties`):**

```properties
brokers=3
controllers=3
schema_registries=1
connect_instances=2
persistent_volumes=true
resource_profile=medium
prometheus=true
control_center=true
```

**Use configuration file:**

```bash
python3 kafka_docker_composer.py --config kafka.properties
```

## Development and Testing

### Running Tests

The project includes a comprehensive test suite:

```bash
# Run all tests
python3 -m unittest discover -s . -p "test_*.py" -v

# Or use the Makefile
make test

# Run with coverage (requires pytest-cov)
pytest --cov=. --cov-report=html --cov-report=term
make coverage
```

### Code Quality

```bash
# Run linter (requires pylint)
pylint kafka_docker_composer.py constants.py logger.py validator.py generators/*.py
make lint

# Format code (requires black)
black kafka_docker_composer.py constants.py logger.py validator.py generators/*.py
make format

# Run all quality checks
make check
```

### Development Workflow

1. **Create a virtual environment:**
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   ```

2. **Install development dependencies:**
   ```bash
   pip install -r requirements-dev.txt
   ```

3. **Make your changes and test:**
   ```bash
   make test
   make lint
   ```

4. **Generate and test a cluster:**
   ```bash
   python3 kafka_docker_composer.py -b 3 -c 3
   docker compose up -d
   docker compose logs -f
   docker compose down
   ```

5. **Clean up:**
   ```bash
   make clean
   ```

### CI/CD

The project includes GitHub Actions workflows in `.github/workflows/`:

- **ci.yml**: Runs tests on multiple Python versions, validates generation, and checks code quality
- Automatic testing on push and pull requests
- Code coverage reporting

### Project Structure

```
kafka-docker-composer/
├── kafka_docker_composer.py    # Main entry point
├── constants.py                # Configuration constants
├── logger.py                   # Logging utilities
├── validator.py                # Configuration validation
├── generators/                 # Component generators
│   ├── broker_generator.py
│   ├── controller_generator.py
│   ├── zookeeper_generator.py
│   ├── schema_registry_generator.py
│   ├── connect_generator.py
│   ├── ksqldb_generator.py
│   └── control_center*.py
├── docker-generator/
│   └── templates/             # Jinja2 templates
├── scripts/                   # Utility scripts
├── volumes/                   # Volume resources
├── tests/                     # Test files
│   ├── test_yaml_generator.py
│   └── test_validators.py
├── requirements.txt           # Dependencies
├── requirements-dev.txt       # Dev dependencies
├── Makefile                   # Development shortcuts
├── setup.py                   # Package setup
├── CONTRIBUTING.md            # Contribution guide
├── CHANGELOG.md               # Version history
└── README.md                  # This file
```

## Documentation

### Project Files

- **README.md** (this file) - Complete user documentation
- **CONTRIBUTING.md** - Contribution guidelines and development workflow
- **CHANGELOG.md** - Project version history and changes
- **LICENSE.md** - Apache 2.0 License
- **requirements.txt** - Python dependencies
- **requirements-dev.txt** - Development dependencies
- **Makefile** - Common development tasks and shortcuts

### Code Documentation

All Python modules include comprehensive inline documentation:

- **kafka_docker_composer.py** - Main generator script
- **logger.py** - Logging configuration module
- **validator.py** - Configuration validation module
- **constants.py** - Configuration constants and profiles
- **generators/*** - Service generator modules

### External Resources

- **Confluent Documentation**: https://docs.confluent.io/
- **Apache Kafka Documentation**: https://kafka.apache.org/documentation/
- **Control Center Guide**: https://docs.confluent.io/platform/current/control-center/
- **Kafka Connect Guide**: https://docs.confluent.io/platform/current/connect/
- **Schema Registry Guide**: https://docs.confluent.io/platform/current/schema-registry/
- **ksqlDB Guide**: https://docs.ksqldb.io/
- **Docker Compose Reference**: https://docs.docker.com/compose/

### Getting Help

**Issues and Questions:**

- Check this README and troubleshooting section
- Review generated logs with `-v` flag
- Inspect container logs: `docker compose logs`
- Check GitHub issues for similar problems

**Contributing:**

Contributions are welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines:
- Development setup and workflow
- Code style and formatting standards
- Testing requirements
- Pull request process
- Bug reporting templates

## License

Apache License 2.0 - See [LICENSE.md](LICENSE.md) for details.

---

**Version**: 1.0.0
**Last Updated**: 2024
**Maintained by**: Kafka Docker Composer Contributors
