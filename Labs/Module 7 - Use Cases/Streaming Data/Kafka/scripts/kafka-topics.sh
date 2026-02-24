#!/bin/bash
# Wrapper script to run kafka-topics without Prometheus JMX errors

# Note: Inside the container, use kafka-1:19094
# Replace localhost:9092 with kafka-1:19094 if found in arguments
ARGS="$@"
ARGS="${ARGS//localhost:9092/kafka-1:19094}"

docker exec kafka-1 sh -c "unset KAFKA_OPTS; kafka-topics $ARGS"
