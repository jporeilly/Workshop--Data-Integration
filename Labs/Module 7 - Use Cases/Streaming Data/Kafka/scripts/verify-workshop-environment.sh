#!/bin/bash

# Pentaho Kafka Workshop - Environment Verification Script
# This script checks if all required components are ready for the workshop

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

ERRORS=0
WARNINGS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Pentaho Kafka Workshop - Environment Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Function to check if a service is running
check_service() {
    local service=$1
    local url=$2
    local description=$3

    echo -n "Checking $description... "
    if curl -s "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "  ${RED}Error: Cannot connect to $url${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if a port is listening
check_port() {
    local port=$1
    local description=$2

    echo -n "Checking $description (port $port)... "
    if nc -z localhost $port 2>/dev/null || netstat -an 2>/dev/null | grep -q ":$port "; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        echo -e "  ${RED}Error: Port $port is not listening${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check Docker container
check_container() {
    local container=$1
    local description=$2

    echo -n "Checking $description container... "
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        echo -e "${GREEN}✓ RUNNING${NC}"
        return 0
    else
        echo -e "${RED}✗ NOT RUNNING${NC}"
        ((ERRORS++))
        return 1
    fi
}

# Function to check if a topic exists and has data
check_topic() {
    local topic=$1

    echo -n "Checking topic: $topic... "

    # Check if topic exists
    if ! docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null | grep -q "^${topic}$"; then
        echo -e "${YELLOW}⚠ NOT FOUND${NC}"
        ((WARNINGS++))
        return 1
    fi

    # Check if topic has data
    local msg_count=$(docker exec kafka-1 kafka-run-class kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic $topic 2>/dev/null | awk -F':' '{sum += $3} END {print sum}')

    if [ "$msg_count" -gt 0 ]; then
        echo -e "${GREEN}✓ OK ($msg_count messages)${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ NO DATA${NC}"
        ((WARNINGS++))
        return 1
    fi
}

# Function to check connector status
check_connector() {
    local connector=$1

    echo -n "Checking connector: $connector... "

    local status=$(curl -s "http://localhost:8083/connectors/$connector/status" 2>/dev/null | jq -r '.connector.state' 2>/dev/null)

    if [ "$status" == "RUNNING" ]; then
        echo -e "${GREEN}✓ RUNNING${NC}"
        return 0
    elif [ "$status" == "FAILED" ] || [ "$status" == "PAUSED" ]; then
        echo -e "${RED}✗ $status${NC}"
        ((ERRORS++))
        return 1
    elif [ -z "$status" ] || [ "$status" == "null" ]; then
        echo -e "${YELLOW}⚠ NOT FOUND${NC}"
        ((WARNINGS++))
        return 1
    else
        echo -e "${YELLOW}⚠ $status${NC}"
        ((WARNINGS++))
        return 1
    fi
}

echo "=== Step 1: Docker Environment ==="
echo ""

# Check if Docker is running
echo -n "Checking Docker daemon... "
if docker info > /dev/null 2>&1; then
    echo -e "${GREEN}✓ RUNNING${NC}"
else
    echo -e "${RED}✗ NOT RUNNING${NC}"
    echo -e "${RED}Error: Docker daemon is not running. Please start Docker.${NC}"
    exit 1
fi

# Check if docker-compose is available
echo -n "Checking docker compose... "
if docker compose version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AVAILABLE${NC}"
elif docker-compose --version > /dev/null 2>&1; then
    echo -e "${GREEN}✓ AVAILABLE (legacy)${NC}"
else
    echo -e "${RED}✗ NOT FOUND${NC}"
    echo -e "${RED}Error: docker compose is not installed${NC}"
    exit 1
fi

echo ""
echo "=== Step 2: Kafka Cluster Components ==="
echo ""

# Check Kafka brokers
check_container "kafka-1" "Kafka Broker 1"
check_container "kafka-2" "Kafka Broker 2"
check_container "kafka-3" "Kafka Broker 3"

# Check Controllers
check_container "controller-1" "Kafka Controller 1"
check_container "controller-2" "Kafka Controller 2"
check_container "controller-3" "Kafka Controller 3"

# Check Kafka Connect
check_container "kafka-connect-1" "Kafka Connect 1"
check_container "kafka-connect-2" "Kafka Connect 2"

# Check Schema Registry
check_container "schema-registry-1" "Schema Registry"

# Check Control Center
check_container "control-center" "Confluent Control Center"

echo ""
echo "=== Step 3: Service Endpoints ==="
echo ""

# Check Kafka broker ports
check_port "9092" "Kafka Broker (external)"

# Check Kafka Connect
check_service "Kafka Connect" "http://localhost:8083" "Kafka Connect REST API"

# Check Schema Registry
check_service "Schema Registry" "http://localhost:8081" "Schema Registry API"

# Check Control Center
check_service "Control Center" "http://localhost:9021" "Confluent Control Center"

echo ""
echo "=== Step 4: Workshop Data Connectors ==="
echo ""

# Check workshop connectors
check_connector "pdi-users-datagen"
check_connector "pdi-stocktrades-datagen"
check_connector "pdi-purchases-datagen"
check_connector "pdi-pageviews-datagen"

echo ""
echo "=== Step 5: Workshop Topics and Data ==="
echo ""

# Check workshop topics
check_topic "pdi-users"
check_topic "pdi-stocktrades"
check_topic "pdi-purchases"
check_topic "pdi-pageviews"

echo ""
echo "=== Step 6: Prerequisites ==="
echo ""

# Check if jq is installed
echo -n "Checking jq (JSON processor)... "
if command -v jq > /dev/null 2>&1; then
    echo -e "${GREEN}✓ INSTALLED${NC}"
else
    echo -e "${YELLOW}⚠ NOT FOUND${NC}"
    echo -e "  ${YELLOW}Warning: jq is recommended for working with Kafka Connect API${NC}"
    echo -e "  Install with: sudo apt install jq (Ubuntu/Debian) or brew install jq (Mac)${NC}"
    ((WARNINGS++))
fi

# Check if nc (netcat) is available
echo -n "Checking netcat... "
if command -v nc > /dev/null 2>&1; then
    echo -e "${GREEN}✓ INSTALLED${NC}"
else
    echo -e "${YELLOW}⚠ NOT FOUND${NC}"
    echo -e "  ${YELLOW}Warning: netcat is useful for testing port connectivity${NC}"
    ((WARNINGS++))
fi

echo ""
echo "========================================"
echo -e "${BLUE}Verification Summary${NC}"
echo "========================================"
echo ""

if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}✓ All checks passed!${NC}"
    echo -e "${GREEN}Your workshop environment is ready!${NC}"
    echo ""
    echo "Next steps:"
    echo "  1. Open Pentaho Spoon"
    echo "  2. Follow the Quick Start guide: cat Workshop/Pentaho-Kafka-EE/QUICK-START.md"
    echo "  3. Access Control Center: http://localhost:9021"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}⚠ Verification completed with $WARNINGS warning(s)${NC}"
    echo -e "${YELLOW}You can proceed, but some optional features may not be available${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Verification failed with $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Common solutions:"
    echo ""
    echo "  If Kafka containers are not running:"
    echo "    docker compose up -d"
    echo ""
    echo "  If connectors are not found:"
    echo "    cd Workshop/Pentaho-Kafka-EE/connectors"
    echo "    ./deploy-connectors.sh"
    echo ""
    echo "  If topics have no data:"
    echo "    Wait 1-2 minutes for connectors to generate data"
    echo "    Check connector status: curl http://localhost:8083/connectors/<name>/status | jq"
    echo ""
    echo "  To restart everything:"
    echo "    docker compose restart"
    echo ""
    exit 1
fi
