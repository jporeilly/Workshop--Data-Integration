"""
Kafka Broker Generator Module

This module generates Docker Compose service configurations for Kafka brokers.
Brokers are the core components that store and serve data in a Kafka cluster.

The generator supports both:
- ZooKeeper-based deployments (legacy)
- KRaft-based deployments (ZooKeeper-less, modern approach)
"""

from .broker_controller_generator import BrokerControllerGenerator
from constants import *


class BrokerGenerator(BrokerControllerGenerator):
    """
    Generator for Kafka broker service configurations.

    This class extends BrokerControllerGenerator to create Docker Compose
    service definitions for Kafka brokers, including:
    - Network listeners (internal and external)
    - Environment variables
    - Health checks
    - Prometheus monitoring configuration
    - Rack awareness for fault tolerance
    """

    def __init__(self, base):
        """
        Initialize the BrokerGenerator.

        Args:
            base: DockerComposeGenerator instance containing shared configuration
        """
        super().__init__(base)

    def generate(self):
        """
        Generate broker service configurations.

        Creates service definitions for the number of brokers specified in
        command-line arguments. Each broker gets:
        - Unique node ID
        - External and internal ports
        - Rack assignment for distribution
        - JMX monitoring ports
        - Health check configuration

        Returns:
            list: List of broker service dictionaries
        """
        base = self.base
        rack = 0  # Starting rack ID for round-robin distribution

        # Lists to collect broker configurations
        brokers = []
        bootstrap_servers = []

        # ========== Configure Prometheus Scraping Job ==========
        # Create a Prometheus job to scrape metrics from all brokers
        targets = []
        job = {
            "name": "kafka-broker",
            "scrape_interval": "5s",  # Scrape metrics every 5 seconds
            "targets": targets  # Will be populated with broker hostnames
        }
        base.prometheus_jobs.append(job)

        # ========== Create Each Broker Configuration ==========
        for broker_id in range(1, base.args.brokers + 1):
            # Allocate unique ports for this broker
            port = base.next_external_broker_port()  # Port for external client connections
            internal_port = base.next_internal_broker_port()  # Port for inter-broker communication
            node_id = base.next_node_id()  # Unique node ID (used in KRaft mode)

            broker = {}

            # ========== Service Naming ==========
            # Create service name (e.g., "kafka-1", "kafka-2")
            name = base.create_name("kafka", broker_id)
            broker["name"] = name
            broker["hostname"] = name
            broker["container_name"] = name

            # Add this broker as a Prometheus scraping target
            targets.append(f"{name}:{JMX_PORT}")

            # ========== Docker Image Configuration ==========
            broker["image"] = f"{base.repository}/{base.args.kafka_container}{base.tc}:" + base.args.release

            # ========== Service Dependencies ==========
            # Brokers depend on either controllers (KRaft) or ZooKeeper (legacy)
            broker["depends_on"] = base.controller_containers[:] if base.use_kraft else base.zookeeper_containers[:]
            # If using next-gen Control Center, also depend on Prometheus
            if base.args.control_center_next_gen:
                broker["depends_on"].append("prometheus")

            # Allocate JMX port for remote monitoring
            jmx_port = base.next_jmx_external_port()

            # ========== Broker Environment Variables ==========
            broker["environment"] = {
                # Network listeners: PLAINTEXT for internal, EXTERNAL for client connections
                "KAFKA_LISTENERS": f"PLAINTEXT://{name}:{internal_port}, EXTERNAL://0.0.0.0:{port}",

                # Security protocol mapping (both using PLAINTEXT, can be changed to SSL/SASL)
                "KAFKA_LISTENER_SECURITY_PROTOCOL_MAP": "PLAINTEXT:PLAINTEXT,EXTERNAL:PLAINTEXT",

                # Advertised listeners: what clients and other brokers use to connect
                "KAFKA_ADVERTISED_LISTENERS": f"PLAINTEXT://{name}:{internal_port}, EXTERNAL://localhost:{port}",

                # Which listener to use for inter-broker communication
                "KAFKA_INTER_BROKER_LISTENER_NAME": "PLAINTEXT",

                # Reduce initial rebalance delay for faster consumer group startup
                "KAFKA_GROUP_INITIAL_REBALANCE_DELAY_MS": 0,

                # JMX monitoring ports
                "KAFKA_JMX_PORT": jmx_port,
                "KAFKA_JMX_HOSTNAME": "localhost",

                # Rack awareness: distribute replicas across racks for fault tolerance
                "KAFKA_BROKER_RACK": f"rack-{rack}",

                # JVM options: enable Prometheus JMX exporter agent
                "KAFKA_OPTS": JMX_PROMETHEUS_JAVA_AGENT + BROKER_JMX_CONFIG,

                # Minimum in-sync replicas for durability (dynamically calculated)
                "KAFKA_MIN_INSYNC_REPLICAS": base.min_insync_replicas(),

                # Confluent-specific features (only enabled if replication factor >= 3)
                "KAFKA_CONFLUENT_CLUSTER_LINK_ENABLE": base.replication_factor() >= 3,
                "KAFKA_CONFLUENT_REPORTERS_TELEMETRY_AUTO_ENABLE": base.replication_factor() >= 3,
            }

            # ========== Confluent Platform Specific Configuration ==========
            # Add Confluent-specific settings (not needed for OSK/Apache Kafka)
            if not base.args.osk:
                broker["environment"]["KAFKA_CONFLUENT_LICENSE_TOPIC_REPLICATION_FACTOR"] = base.replication_factor()
                broker["environment"]["KAFKA_METRIC_REPORTERS"] = "io.confluent.metrics.reporter.ConfluentMetricsReporter"

            # ========== Next-Gen Control Center Configuration ==========
            # Add additional environment variables for next-gen Control Center integration
            if base.args.control_center_next_gen:
                self.generate_c3plusplus(broker["environment"])

            # ========== KRaft vs ZooKeeper Configuration ==========
            # Different configuration depending on cluster mode
            controller_dict = {}

            if base.use_kraft:
                # KRaft mode configuration (ZooKeeper-less)
                controller_dict["KAFKA_NODE_ID"] = node_id
                controller_dict["CLUSTER_ID"] = base.args.uuid  # Cluster UUID required for KRaft
                controller_dict["KAFKA_CONTROLLER_QUORUM_VOTERS"] = base.quorum_voters  # List of controller nodes
                controller_dict["KAFKA_PROCESS_ROLES"] = 'broker'  # This node only acts as a broker
                controller_dict["KAFKA_CONTROLLER_LISTENER_NAMES"] = "CONTROLLER"

                # Add CONTROLLER protocol to security map
                controller_dict["KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"] = \
                    "CONTROLLER:PLAINTEXT" + "," + broker["environment"]["KAFKA_LISTENER_SECURITY_PROTOCOL_MAP"]
            else:
                # ZooKeeper mode configuration (legacy)
                controller_dict["KAFKA_DEFAULT_REPLICATION_FACTOR"] = base.replication_factor()
                controller_dict["KAFKA_BROKER_ID"] = broker_id  # Simple numeric ID in ZK mode
                controller_dict["KAFKA_ZOOKEEPER_CONNECT"] = base.zookeepers  # ZooKeeper connection string
                controller_dict["KAFKA_CONFLUENT_METRICS_REPORTER_TOPIC_REPLICAS"] = base.replication_factor()

            # Merge KRaft/ZooKeeper specific settings into environment
            broker["environment"].update(controller_dict)

            # ========== Container Capabilities ==========
            # NET_ADMIN capability allows traffic control (tc) commands
            # Required if using --with-tc flag for network simulation
            broker["cap_add"] = [
                "NET_ADMIN"
            ]

            # ========== Port Mappings ==========
            # Map container ports to host ports
            broker["ports"] = {
                port: port,  # Kafka client port (external)
                jmx_port: jmx_port,  # JMX remote monitoring port
                base.next_agent_port(): JMX_PORT,  # Prometheus JMX exporter port
                base.next_http_port(): 8090  # HTTP/REST port
            }

            # ========== Volume Mounts ==========
            # Mount JMX exporter JAR and configuration files
            broker["volumes"] = [
                LOCAL_VOLUMES + JMX_JAR_FILE + ":/tmp/" + JMX_JAR_FILE,
                LOCAL_VOLUMES + BROKER_JMX_CONFIG + ":/tmp/" + BROKER_JMX_CONFIG
            ]

            # ========== Health Check Configuration ==========
            # Docker will use this to determine if the broker is healthy
            broker["healthcheck"] = {
                "test": f"{base.healthcheck_command} cluster-id --bootstrap-server localhost:{port} || exit 1",
                "interval": "10s",  # Check every 10 seconds
                "retries": "10",  # Retry 10 times before marking unhealthy
                "start_period": "20s"  # Grace period during startup
            }

            # ========== Apply Resource Limits ==========
            # Add CPU and memory limits if resource profile is configured
            base.add_resource_limits(broker, 'broker')

            # Add completed broker to list
            brokers.append(broker)
            # Add to bootstrap servers list (using internal port for inter-container communication)
            bootstrap_servers.append(f"{name}:{internal_port}")

            # Move to next rack (round-robin distribution)
            rack = base.next_rack(rack, base.args.racks)

        # ========== Post-Processing ==========
        # After all brokers are created, set global bootstrap servers
        if base.args.brokers > 0:
            base.bootstrap_servers = ",".join(bootstrap_servers)

        # Save broker container names for dependency management
        base.broker_containers = [b["name"] for b in brokers]

        # ========== Configure Metrics Reporter Bootstrap Servers ==========
        # Set bootstrap servers for metrics reporting on all brokers
        for broker in brokers:
            broker["environment"]["KAFKA_CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS"] = base.bootstrap_servers

        # Also update controllers if they exist (for KRaft mode)
        for controller in base.controllers:
            controller["environment"]["KAFKA_CONFLUENT_METRICS_REPORTER_BOOTSTRAP_SERVERS"] = base.bootstrap_servers

        return brokers
