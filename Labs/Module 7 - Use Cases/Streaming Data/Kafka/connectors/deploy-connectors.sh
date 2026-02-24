#!/bin/bash

# Script to deploy all Pentaho PDI workshop datagen connectors
# This creates continuous streaming data sources for the workshop

CONNECT_URL="http://localhost:8083"
CONNECTORS_DIR="$(dirname "$0")"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Pentaho PDI Kafka Workshop - Connector Deployment${NC}"
echo "==========================================="
echo ""

# Wait for Kafka Connect to be ready
echo "Waiting for Kafka Connect to be ready..."
until curl -s "$CONNECT_URL" > /dev/null 2>&1; do
    echo -n "."
    sleep 2
done
echo -e "\n${GREEN}Kafka Connect is ready!${NC}\n"

# Function to deploy a connector
deploy_connector() {
    local connector_file=$1
    local connector_name=$(basename "$connector_file" .json)

    echo -e "Deploying connector: ${YELLOW}$connector_name${NC}"

    # Check if connector already exists
    if curl -s "$CONNECT_URL/connectors/$connector_name" > /dev/null 2>&1; then
        echo -e "${YELLOW}Connector $connector_name already exists. Deleting...${NC}"
        curl -s -X DELETE "$CONNECT_URL/connectors/$connector_name" > /dev/null
        sleep 2
    fi

    # Deploy the connector
    response=$(curl -s -X POST "$CONNECT_URL/connectors" \
        -H "Content-Type: application/json" \
        -d @"$connector_file")

    if echo "$response" | grep -q "error_code"; then
        echo -e "${RED}Failed to deploy $connector_name${NC}"
        echo "$response" | jq
    else
        echo -e "${GREEN}Successfully deployed $connector_name${NC}"
    fi

    echo ""
}

# Deploy all connector configurations
echo "Deploying workshop connectors..."
echo ""

deploy_connector "$CONNECTORS_DIR/pdi-users-datagen.json"
deploy_connector "$CONNECTORS_DIR/pdi-stocktrades-datagen.json"
deploy_connector "$CONNECTORS_DIR/pdi-purchases-datagen.json"
deploy_connector "$CONNECTORS_DIR/pdi-pageviews-datagen.json"

# Wait a moment for connectors to initialize
sleep 3

# Fix topic configurations (min.insync.replicas should match replication factor)
echo "==========================================="
echo -e "${YELLOW}Fixing topic configurations...${NC}"
echo ""

for topic in pdi-users pdi-pageviews pdi-purchases pdi-stocktrades; do
    echo "Setting min.insync.replicas=1 for $topic"
    docker exec kafka-1 sh -c "unset KAFKA_OPTS; kafka-configs --bootstrap-server kafka-1:19094 --entity-type topics --entity-name $topic --alter --add-config min.insync.replicas=1" > /dev/null 2>&1
done

echo -e "${GREEN}Topic configurations updated${NC}"
echo ""

# Check connector status
echo "==========================================="
echo -e "${YELLOW}Connector Status:${NC}"
echo ""

for connector in pdi-users-datagen pdi-stocktrades-datagen pdi-purchases-datagen pdi-pageviews-datagen; do
    status=$(curl -s "$CONNECT_URL/connectors/$connector/status" | jq -r '.connector.state')
    if [ "$status" == "RUNNING" ]; then
        echo -e "$connector: ${GREEN}$status${NC}"
    else
        echo -e "$connector: ${RED}$status${NC}"
    fi
done

echo ""
echo "==========================================="
echo -e "${GREEN}Deployment Complete!${NC}"
echo ""
echo "Topics created:"
echo "  - pdi-users         (1 record/sec, user registration data)"
echo "  - pdi-stocktrades   (10 records/sec, stock trading data)"
echo "  - pdi-purchases     (2 records/sec, purchase transactions)"
echo "  - pdi-pageviews     (5 records/sec, website pageviews)"
echo ""
echo "View in Confluent Control Center: http://localhost:9021"
echo "Kafka Connect REST API: $CONNECT_URL"
echo ""
echo "To check connector status:"
echo "  curl $CONNECT_URL/connectors/<connector-name>/status | jq"
echo ""
echo "To view topic data (recommended - no Prometheus errors):"
echo "  ./scripts/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic pdi-users --from-beginning --max-messages 10"
echo ""
echo "Or use make commands:"
echo "  make consume-users"
echo "  make consume-trades"
echo ""
