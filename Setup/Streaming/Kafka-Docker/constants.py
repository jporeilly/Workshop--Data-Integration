"""
Kafka Docker Composer - Constants and Configuration

This module defines all constants used throughout the Kafka Docker Composer application.
These include Docker image versions, port numbers, file paths, and default configuration values.
"""

# ========== Cluster Identification ==========
# Unique identifier for the Kafka cluster (used in KRaft mode)
RANDOM_UUID = "Nk018hRAQFytWskYqtQduw"

# ========== Docker Image Versions ==========
# Default Confluent Platform version for all components
DEFAULT_RELEASE = "7.9.5"

# Version for next-generation Control Center and Prometheus
CONTROL_CENTER_NEXT_GEN_RELEASE = "2.3.0"

# ========== Confluent Platform Configuration ==========
# Docker repository and image names for Confluent Platform
CONFLUENT_REPOSITORY = "confluentinc"
CONFLUENT_CONTAINER = "cp-server"  # Confluent Server (includes Kafka + additional features)
CONFLUENT_KAFKA_CLUSTER_CMD = "/usr/bin/kafka-cluster"  # Path to kafka-cluster command in Confluent images

# ========== Apache Kafka (OSK) Configuration ==========
# Docker repository and image names for Open Source Kafka
APACHE_REPOSITORY = "apache"
APACHE_CONTAINER = "kafka"
OSK_KAFKA_CLUSTER_CMD = "/opt/kafka/bin/kafka-cluster.sh"  # Path to kafka-cluster command in Apache images

# ========== Local Build Configuration ==========
# Repository name for locally-built images with traffic control enabled
LOCALBUILD = "localbuild"

# ========== JMX Monitoring Configuration ==========
# JMX (Java Management Extensions) is used for monitoring Java applications

# Prometheus JMX Exporter configuration
JMX_PROMETHEUS_JAVA_AGENT_VERSION = "1.5.0"
JMX_PORT = "8091"  # Port where JMX exporter exposes metrics
JMX_JAR_FILE = f"jmx_prometheus_javaagent-{JMX_PROMETHEUS_JAVA_AGENT_VERSION}.jar"
JMX_PROMETHEUS_JAVA_AGENT = f"-javaagent:/tmp/{JMX_JAR_FILE}={JMX_PORT}:/tmp/"

# Starting port numbers for JMX-related services (incremented for each instance)
JMX_EXTERNAL_PORT = 10000  # JMX external port for remote monitoring
JMX_AGENT_PORT = 10100     # JMX agent port for Prometheus exporter
HTTP_PORT = 10200          # HTTP port for additional services

# ========== Kafka Broker Port Configuration ==========
# Base port numbers for Kafka brokers (incremented for each broker)
BROKER_EXTERNAL_BASE_PORT = 9090   # External port for client connections (from host)
BROKER_INTERNAL_BASE_PORT = 19090  # Internal port for inter-broker communication

# ========== File System Paths ==========
# Path to the volumes directory (contains configuration files and data)
LOCAL_VOLUMES = "$PWD/volumes/"

# Default output file name for generated docker-compose configuration
DOCKER_COMPOSE_FILE = "docker-compose.yml"

# ========== JMX Configuration File Names ==========
# YAML files containing JMX metric collection rules for each component
ZOOKEEPER_JMX_CONFIG = "zookeeper_config.yml"
BROKER_JMX_CONFIG = "kafka_config.yml"
CONTROLLER_JMX_CONFIG = "kafka_controller.yml"
SCHEMA_REGISTRY_JMX_CONFIG = "schema-registry.yml"
CONNECT_JMX_CONFIG = "kafka_connect.yml"

# ========== Service Port Numbers ==========
# Default port for ZooKeeper client connections
ZOOKEEPER_PORT = "2181"

# ========== Resource Profiles ==========
# Predefined resource limits for different deployment sizes
RESOURCE_PROFILES = {
    'small': {
        'broker_memory': '512m',
        'broker_heap': '256m',
        'broker_cpus': '0.5',
        'controller_memory': '512m',
        'controller_heap': '256m',
        'controller_cpus': '0.5',
        'zookeeper_memory': '256m',
        'zookeeper_heap': '128m',
        'zookeeper_cpus': '0.25',
        'schema_registry_memory': '256m',
        'schema_registry_cpus': '0.25',
        'connect_memory': '512m',
        'connect_heap': '256m',
        'connect_cpus': '0.5',
    },
    'medium': {
        'broker_memory': '2g',
        'broker_heap': '1g',
        'broker_cpus': '1.0',
        'controller_memory': '1g',
        'controller_heap': '512m',
        'controller_cpus': '0.5',
        'zookeeper_memory': '512m',
        'zookeeper_heap': '256m',
        'zookeeper_cpus': '0.5',
        'schema_registry_memory': '512m',
        'schema_registry_cpus': '0.5',
        'connect_memory': '1g',
        'connect_heap': '512m',
        'connect_cpus': '1.0',
    },
    'large': {
        'broker_memory': '4g',
        'broker_heap': '2g',
        'broker_cpus': '2.0',
        'controller_memory': '2g',
        'controller_heap': '1g',
        'controller_cpus': '1.0',
        'zookeeper_memory': '1g',
        'zookeeper_heap': '512m',
        'zookeeper_cpus': '1.0',
        'schema_registry_memory': '1g',
        'schema_registry_cpus': '1.0',
        'connect_memory': '2g',
        'connect_heap': '1g',
        'connect_cpus': '2.0',
    }
}
