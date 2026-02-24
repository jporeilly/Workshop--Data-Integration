#!/bin/bash

# List Kafka topics (suppressing Prometheus errors)
docker exec kafka-1 kafka-topics --bootstrap-server localhost:9092 --list 2>&1 | grep -v "Prometheus\|JavaAgent\|BindException\|HTTPServer\|sun.nio\|java.base"
