#!/bin/bash

# Consume messages from a Kafka topic without Prometheus errors
# Usage: ./consume-topic.sh <topic-name> [max-messages]

TOPIC=${1:-pdi-users}
MAX_MESSAGES=${2:-10}

echo "Consuming from topic: $TOPIC (max messages: $MAX_MESSAGES)"
echo "================================================"

docker exec kafka-1 kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic "$TOPIC" \
  --from-beginning \
  --max-messages "$MAX_MESSAGES" \
  2>&1 | grep -v "Prometheus\|JavaAgent\|BindException\|HTTPServer\|sun.nio\|java.base\|jdk.http\|java.instrument" | grep -v "^$" | grep -v "^\s*at "
