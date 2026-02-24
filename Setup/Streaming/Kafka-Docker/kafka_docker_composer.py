"""
Kafka Docker Composer - Main Script

This script generates a docker-compose.yml file for running a Confluent Kafka cluster
with various components including brokers, controllers, schema registry, connect, ksqlDB,
Control Center, Prometheus, and Grafana.

The script supports both ZooKeeper-based and KRaft (ZooKeeper-less) deployments.

Usage:
    python3 kafka_docker_composer.py [options]

Example:
    python3 kafka_docker_composer.py -b 3 -c 3 -p -s 1 -C 2 --control-center
"""

import argparse
import sys

import configparser

from jinja2 import Environment, PackageLoader, select_autoescape

# Import all component generators
from generators.broker_generator import BrokerGenerator
from generators.connect_generator import ConnectGenerator
from generators.control_center_generator import ControlCenterGenerator
from generators.control_center_next_gen_generator import ControlCenterNextGenerationGenerator
from generators.controller_generator import ControllerGenerator
from generators.ksqldb_generator import KSQLDBGenerator
from generators.schema_registry_generator import SchemaRegistryGenerator
from generators.zookeeper_generator import ZooKeeperGenerator

# Import all constants used throughout the application
from constants import *

# Import logging and validation modules
from logger import setup_logging, get_logger
from validator import validate_configuration, ValidationError, ValidationWarning

class Generator:
    """
    Base generator class (unused but kept for potential future extensions).

    Attributes:
        base: Base configuration object
    """
    def __init__(self, base):
        self.base = base

    def generate(self):
        """Generate configuration (to be implemented by subclasses)"""
        pass


class DockerComposeGenerator:
    """
    Main generator class for creating docker-compose.yml and prometheus.yml files.

    This class orchestrates the generation of all Kafka-related services including
    controllers, brokers, schema registry, connect, ksqlDB, and monitoring tools.

    Attributes:
        args: Command-line arguments containing configuration options
        env: Jinja2 environment for template rendering
        repository: Docker repository to pull images from
        tc: Traffic control suffix for local builds
        zookeepers: Comma-separated list of ZooKeeper instances
        quorum_voters: Comma-separated list of KRaft controller voters
        bootstrap_servers: Comma-separated list of broker bootstrap servers
        schema_registries: Comma-separated list of schema registry instances
        schema_registry_urls: URLs for schema registry endpoints
        connect_urls: URLs for Kafka Connect endpoints
        ksqldb_urls: URLs for ksqlDB endpoints
        healthcheck_command: Command used for broker health checks
        controllers: List of controller instances
        controller_containers: List of controller container names
        zookeeper_containers: List of ZooKeeper container names
        broker_containers: List of broker container names
        connect_containers: List of Connect container names
        schema_registry_containers: List of Schema Registry container names
        ksqldb_containers: List of ksqlDB container names
        prometheus_jobs: List of Prometheus scraping jobs
        jmx_external_port_counter: Counter for JMX external ports
        agent_port_counter: Counter for JMX agent ports
        http_port_counter: Counter for HTTP ports
        use_kraft: Boolean indicating if KRaft mode is enabled
        node_id: Counter for broker node IDs
        controller_node_id: Counter for controller node IDs
        internal_port: Counter for internal broker ports
        external_port: Counter for external broker ports
    """
    def __init__(self, arguments):
        """
        Initialize the DockerComposeGenerator with command-line arguments.

        Args:
            arguments: Parsed command-line arguments from argparse
        """
        self.args = arguments

        # Initialize Jinja2 template environment for rendering docker-compose files
        self.env = Environment(
            loader=PackageLoader("docker-generator"),
            autoescape=select_autoescape(),
            trim_blocks=True,  # Remove newlines after template tags
            lstrip_blocks=True  # Remove leading whitespace before template tags
        )

        # Determine which Docker repository to use
        if self.args.with_tc:
            # Use local build with traffic control enabled
            self.repository = LOCALBUILD
            self.tc = "-tc"
        else:
            # Use specified repository (Confluent or Apache)
            self.repository = self.args.repository
            self.tc = ""

        # Initialize service URL lists (populated by generators)
        self.zookeepers = ""
        self.quorum_voters = ""
        self.bootstrap_servers = ""
        self.schema_registries = ""
        self.schema_registry_urls = ""
        self.connect_urls = ""
        self.ksqldb_urls = ""

        # Set health check command based on Kafka distribution (OSK vs Confluent)
        self.healthcheck_command = "KAFKA_OPTS= " + (OSK_KAFKA_CLUSTER_CMD if self.args.osk else CONFLUENT_KAFKA_CLUSTER_CMD)

        # Initialize controller list
        self.controllers = []

        # Initialize container name lists for dependency management
        self.controller_containers = []
        self.zookeeper_containers = []
        self.broker_containers = []
        self.connect_containers = []
        self.schema_registry_containers = []
        self.ksqldb_containers = []

        # Initialize Prometheus jobs list
        self.prometheus_jobs = []

        # Initialize port counters (incremented as services are added)
        self.jmx_external_port_counter = JMX_EXTERNAL_PORT
        self.agent_port_counter = JMX_AGENT_PORT
        self.http_port_counter = HTTP_PORT

        # Determine if KRaft mode is enabled (controllers > 0 means no ZooKeeper)
        self.use_kraft = self.args.controllers > 0

        # Initialize node ID counters
        # Broker node IDs start from 1
        self.node_id = 0
        # Controller node IDs start from 1001 to avoid conflicts with brokers
        self.controller_node_id = 1000

        # Initialize port counters for brokers
        self.internal_port = BROKER_INTERNAL_BASE_PORT
        self.external_port = BROKER_EXTERNAL_BASE_PORT

        # Get resource profile
        self.resource_profile = self._get_resource_profile()

    def next_jmx_external_port(self):
        """
        Get the next available JMX external port number.

        Returns:
            int: Next JMX external port number
        """
        self.jmx_external_port_counter += 1
        return self.jmx_external_port_counter

    def next_agent_port(self):
        """
        Get the next available JMX agent port number.

        Returns:
            int: Next JMX agent port number
        """
        self.agent_port_counter += 1
        return self.agent_port_counter

    def next_http_port(self):
        """
        Get the next available HTTP port number.

        Returns:
            int: Next HTTP port number
        """
        self.http_port_counter += 1
        return self.http_port_counter

    def next_node_id(self):
        """
        Get the next available broker node ID.

        Returns:
            int: Next broker node ID (starts from 1)
        """
        self.node_id += 1
        return self.node_id

    def next_controller_node_id(self):
        """
        Get the next available controller node ID.

        Returns:
            int: Next controller node ID (starts from 1001)
        """
        self.controller_node_id += 1
        return self.controller_node_id

    def next_internal_broker_port(self):
        """
        Get the next available internal broker port number.

        Returns:
            int: Next internal broker port (for inter-broker communication)
        """
        self.internal_port += 1
        return self.internal_port

    def next_external_broker_port(self):
        """
        Get the next available external broker port number.

        Returns:
            int: Next external broker port (for client connections)
        """
        self.external_port += 1
        return self.external_port

    def _get_resource_profile(self):
        """
        Get the resource profile configuration based on arguments.

        Returns:
            dict: Resource limits for various components, or None if no limits
        """
        if self.args.resource_profile == 'none':
            return None

        from constants import RESOURCE_PROFILES
        profile = RESOURCE_PROFILES.get(self.args.resource_profile, {}).copy()

        # Override with custom values if provided
        if self.args.custom_broker_memory:
            profile['broker_memory'] = self.args.custom_broker_memory
        if self.args.custom_broker_cpus:
            profile['broker_cpus'] = self.args.custom_broker_cpus

        return profile

    def add_resource_limits(self, service, component_type):
        """
        Add resource limits to a service configuration.

        Args:
            service (dict): Service configuration dictionary
            component_type (str): Type of component (broker, controller, zookeeper, etc.)

        Returns:
            dict: Service with added resource limits (if profile is set)
        """
        if not self.resource_profile:
            return service

        memory_key = f"{component_type}_memory"
        cpu_key = f"{component_type}_cpus"
        heap_key = f"{component_type}_heap"

        if memory_key in self.resource_profile:
            # Add deploy section for resource limits
            service["deploy"] = {
                "resources": {
                    "limits": {
                        "memory": self.resource_profile[memory_key]
                    },
                    "reservations": {
                        "memory": self.resource_profile[memory_key]
                    }
                }
            }

            # Add CPU limits if available
            if cpu_key in self.resource_profile:
                service["deploy"]["resources"]["limits"]["cpus"] = self.resource_profile[cpu_key]
                # Reserve 50% of CPU limit
                cpu_reservation = float(self.resource_profile[cpu_key]) * 0.5
                service["deploy"]["resources"]["reservations"]["cpus"] = str(cpu_reservation)

            # Add heap size to environment if applicable
            if heap_key in self.resource_profile and "environment" in service:
                heap_size = self.resource_profile[heap_key]
                if "KAFKA_HEAP_OPTS" not in service["environment"]:
                    service["environment"]["KAFKA_HEAP_OPTS"] = f"-Xmx{heap_size} -Xms{heap_size}"

        return service

    def generate(self):
        """
        Generate all configuration files (docker-compose.yml and prometheus.yml).

        This is the main entry point that orchestrates the generation process.
        """
        self.generate_services()
        self.generate_prometheus()

    def replication_factor(self):
        """
        Calculate the appropriate replication factor based on cluster configuration.

        In shared mode, controllers can also act as brokers, so they count toward
        the total available nodes. The replication factor is capped at 3 for stability.

        Returns:
            int: Replication factor (max 3, min 1)
        """
        if self.args.shared_mode:
            return min(3, self.args.brokers + self.args.controllers)
        else:
            return min(3, self.args.brokers)

    def min_insync_replicas(self):
        """
        Calculate the minimum in-sync replicas based on replication factor.

        This ensures data durability by requiring at least (replication_factor - 1)
        replicas to acknowledge writes, but never less than 1.

        Returns:
            int: Minimum in-sync replicas
        """
        return max(1, self.replication_factor() - 1)

    def generate_services(self):
        """
        Generate all Kafka-related services and create the docker-compose.yml file.

        This method orchestrates the creation of all service configurations by:
        1. Instantiating all component generators
        2. Collecting service definitions from each generator
        3. Adding monitoring services (Prometheus, Grafana, AlertManager)
        4. Rendering the Jinja2 template with all services
        5. Writing the final docker-compose.yml file
        """
        services = []

        # Instantiate all component generators
        zookeeper_generator = ZooKeeperGenerator(self)
        controller_generator = ControllerGenerator(self)
        broker_generator = BrokerGenerator(self)
        schema_registry_generator = SchemaRegistryGenerator(self)
        connect_generator = ConnectGenerator(self)
        ksqldb_generator = KSQLDBGenerator(self)
        control_center_generator = ControlCenterGenerator(self)
        control_center_next_gen_generator = ControlCenterNextGenerationGenerator(self)

        # Generate service configurations from each generator
        # Note: Each generator returns an empty list if the component is not requested
        services += zookeeper_generator.generate()
        services += controller_generator.generate()
        services += broker_generator.generate()
        services += schema_registry_generator.generate()
        services += connect_generator.generate()
        services += ksqldb_generator.generate()
        services += control_center_generator.generate()
        services += control_center_next_gen_generator.generate()

        # Add monitoring and management services
        services += self.generate_prometheus_service()
        services += self.generate_grafana_service()
        services += self.generate_alertmanager_service()

        # Generate Docker volumes if persistence is enabled
        volumes = self.generate_volumes() if self.args.persistent_volumes else None

        # Prepare template variables
        variables = {
            "docker_compose_version": "3.8",
            "services": services,
            "volumes": volumes
        }

        # Render the docker-compose template
        template = self.env.get_template('docker-compose.j2')
        result = template.render(variables)

        # Write the generated docker-compose.yml file
        with open(self.args.docker_compose_file, "w") as yaml_file:
            yaml_file.write(result)

    def generate_volumes(self):
        """
        Generate Docker volume definitions for data persistence.

        Returns:
            dict: Dictionary of volume definitions for docker-compose
        """
        volumes = {}

        # Create volumes for each broker
        for broker_id in range(1, self.args.brokers + 1):
            volumes[f"kafka-{broker_id}-data"] = {"driver": self.args.volume_driver}
            volumes[f"kafka-{broker_id}-logs"] = {"driver": self.args.volume_driver}

        # Create volumes for each controller (KRaft mode)
        for controller_id in range(1, self.args.controllers + 1):
            volumes[f"controller-{controller_id}-data"] = {"driver": self.args.volume_driver}
            volumes[f"controller-{controller_id}-logs"] = {"driver": self.args.volume_driver}

        # Create volumes for each ZooKeeper
        for zk_id in range(1, self.args.zookeepers + 1):
            volumes[f"zookeeper-{zk_id}-data"] = {"driver": self.args.volume_driver}
            volumes[f"zookeeper-{zk_id}-logs"] = {"driver": self.args.volume_driver}

        # Prometheus and Grafana data
        if self.args.prometheus:
            volumes["prometheus-data"] = {"driver": self.args.volume_driver}
            volumes["grafana-data"] = {"driver": self.args.volume_driver}

        return volumes

    def generate_prometheus(self):
        """
        Generate the Prometheus configuration file (prometheus.yml).

        This file contains all the scraping jobs for collecting metrics from
        Kafka brokers, controllers, and other components.
        """
        template = self.env.get_template('prometheus.j2')

        # Prepare variables for the Prometheus template
        variables = {
            "jobs": self.prometheus_jobs
        }
        result = template.render(variables)

        # Write the Prometheus configuration file
        with open('volumes/prometheus.yml', "w") as yaml_file:
            yaml_file.write(result)

    @staticmethod
    def create_name(basename, counter):
        """
        Create a service name by combining a base name with a counter.

        Args:
            basename (str): Base name for the service (e.g., "kafka", "controller")
            counter (int): Numeric suffix for the service

        Returns:
            str: Formatted service name (e.g., "kafka-1", "controller-2")
        """
        return f"{basename}-{counter}"

    def generate_depends_on(self):
        """
        Generate the dependency list for services that depend on the Kafka cluster.

        In shared mode, both controllers and brokers are included in dependencies
        since controllers can also act as brokers.

        Returns:
            list: List of container names that should be started before dependent services
        """
        if self.args.shared_mode:
            return self.controller_containers + self.broker_containers + self.schema_registry_containers
        else:
            return self.broker_containers + self.schema_registry_containers

    def generate_prometheus_service(self):
        """
        Generate the Prometheus service configuration.

        Prometheus is used for metrics collection and monitoring across all
        Kafka components. It scrapes metrics from JMX exporters running on
        brokers, controllers, and other services.

        Returns:
            list: List containing the Prometheus service definition (or empty if not enabled)
        """
        proms = []
        if self.args.prometheus:
            volumes = [
                # Mount the generated Prometheus configuration
                "$PWD/volumes/prometheus.yml:/etc/confluent-control-center/prometheus-generated.yml",
                # Mount volumes directory for persistent data
                "$PWD/volumes/"
            ]

            # Add persistent volume for Prometheus data if enabled
            if self.args.persistent_volumes:
                volumes.append("prometheus-data:/prometheus")

            prometheus = {
                "name": "prometheus",
                "hostname": "prometheus",
                "container_name": "prometheus",
                "image": "confluentinc/cp-enterprise-prometheus:" + self.args.control_center_next_gen_release,
                "ports": {
                    9090: 9090  # Prometheus web UI and API port
                },
                "volumes": volumes
            }
            proms.append(prometheus)

        return proms

    def generate_grafana_service(self):
        """
        Generate the Grafana service configuration.

        Grafana provides visualization dashboards for Kafka metrics collected
        by Prometheus. It's only included if Prometheus monitoring is enabled.

        Returns:
            list: List containing the Grafana service definition (or empty if not enabled)
        """
        grafanas = []
        if self.args.prometheus:
            volumes = [
                # Mount Grafana provisioning configuration (data sources, dashboards)
                "$PWD/volumes/provisioning:/etc/grafana/provisioning",
                # Mount dashboard JSON files
                "$PWD/volumes/dashboards:/var/lib/grafana/dashboards",
                # Mount Grafana configuration file
                "$PWD/volumes/config.ini:/etc/grafana/config.ini"
            ]

            # Add persistent volume for Grafana data if enabled
            if self.args.persistent_volumes:
                volumes.append("grafana-data:/var/lib/grafana")

            grafana = {
                "name": "grafana",
                "hostname": "grafana",
                "container_name": "grafana",
                "image": "grafana/grafana",
                "depends_on": [
                    "prometheus"  # Grafana needs Prometheus as a data source
                ],
                "ports": {
                    3000: 3000  # Grafana web UI port
                },
                "volumes": volumes,
                "environment": {
                    "GF_PATHS_CONFIG": "/etc/grafana/config.ini"
                }
            }
            grafanas.append(grafana)

        return grafanas

    def generate_alertmanager_service(self):
        """
        Generate the AlertManager service configuration.

        AlertManager handles alerts sent by Prometheus server, providing grouping,
        deduplication, and routing to notification receivers. It's only included
        when using the next-generation Control Center.

        Returns:
            list: List containing the AlertManager service definition (or empty if not enabled)
        """
        alertmanagers = []
        if self.args.control_center_next_gen:
            alertmanager = {
                "name": "alertmanager",
                "hostname": "cp-enterprise-alertmanager",
                "container_name": "alertmanager",
                "image": f"{self.args.repository}/cp-enterprise-alertmanager:" + self.args.control_center_next_gen_release,
                "depends_on": [
                    "prometheus"  # AlertManager receives alerts from Prometheus
                ],
                "ports" : {
                    29093 : 9093  # AlertManager web UI and API port
                },
                "volumes": {
                    # Mount configuration directory for alert routing rules
                    LOCAL_VOLUMES + "config:/mnt/config"
                }
            }
            alertmanagers.append(alertmanager)

        return alertmanagers

    @staticmethod
    def next_rack(rack, total_racks):
        """
        Calculate the next rack ID for distributing brokers across racks.

        This implements round-robin distribution of brokers across multiple racks
        to ensure fault tolerance at the rack level.

        Args:
            rack (int): Current rack ID
            total_racks (int): Total number of racks available

        Returns:
            int: Next rack ID (wraps back to 0 after reaching total_racks)
        """
        rack = rack + 1
        if rack >= total_racks:
            rack = 0
        return rack


def load_configfile(arguments, configfile):
    """
    Load configuration from a properties file and override command-line arguments.

    This function reads a properties file (key=value format) and updates the
    argument namespace with values from the file. Values are type-cast based on
    the original argument's type to maintain int/string types correctly.

    Args:
        arguments: argparse.Namespace object containing parsed command-line arguments
        configfile (str): Path to the configuration file

    Returns:
        argparse.Namespace: Updated arguments object with values from config file
    """
    config_parser = configparser.ConfigParser()
    with open(configfile) as f:
        # ConfigParser requires sections, so add a dummy [top] section
        # This allows us to use simple key=value properties files
        lines = '[top]\n' + f.read()
        config_parser.read_string(lines)

    # Iterate through all config items and update arguments
    for k, v in config_parser.items('top'):
        # Type casting: preserve the original argument type
        # If the original argument was an int, cast the config value to int
        # Otherwise, keep it as a string

        if type(arguments.__getattribute__(k)) == int:
            arguments.__setattr__(k, int(v))
        else:
            arguments.__setattr__(k, v)

    return arguments


if __name__ == '__main__':
    """
    Main entry point for the Kafka Docker Composer script.

    Parses command-line arguments, validates configuration, generates docker-compose.yml
    and prometheus.yml files.
    """
    parser = argparse.ArgumentParser(description="Kafka docker-compose Generator")

    # ========== Docker Image Configuration ==========
    # Arguments for controlling which Docker images to use

    parser.add_argument('-r', '--release', default=DEFAULT_RELEASE,
                        help=f"Docker images release version [{DEFAULT_RELEASE}]")
    parser.add_argument('--repository', default=CONFLUENT_REPOSITORY,
                        help=f"Docker repository for images [{CONFLUENT_REPOSITORY}]")
    parser.add_argument('--kafka-container', default=CONFLUENT_CONTAINER,
                        help=f"Container image name for Kafka [{CONFLUENT_CONTAINER}]")

    # ========== Kafka Distribution Options ==========

    parser.add_argument('--osk', action="store_true",
                        help="Use Open Source Apache Kafka instead of Confluent Platform")

    # ========== Advanced Configuration Options ==========

    parser.add_argument('--with-tc', action="store_true",
                        help="Build and use a local Docker image with traffic control (tc) enabled")
    parser.add_argument("--shared-mode", action="store_true",
                        help="Enable shared mode where controllers also act as brokers (KRaft combined mode)")

    # ========== Kafka Cluster Component Counts ==========
    # Arguments for specifying how many of each component to create

    parser.add_argument('-b', '--brokers', default=1, type=int,
                        help="Number of Kafka broker instances [default: 1]")
    parser.add_argument('-z', '--zookeepers', default=0, type=int,
                        help="Number of ZooKeeper instances [default: 0] - mutually exclusive with controllers")
    parser.add_argument('-c', '--controllers', default=0, type=int,
                        help="Number of Kafka controller instances (KRaft mode) [default: 0] - mutually exclusive with zookeepers")
    parser.add_argument('-s', '--schema-registries', default=0, type=int,
                        help="Number of Schema Registry instances [default: 0]")
    parser.add_argument('-C', '--connect-instances', default=0, type=int,
                        help="Number of Kafka Connect worker instances [default: 0]")
    parser.add_argument('-k', '--ksqldb-instances', default=0, type=int,
                        help="Number of ksqlDB server instances [default: 0]")

    # ========== Management and Monitoring Components ==========

    parser.add_argument('--control-center', default=False, action='store_true',
                        help="Include Confluent Control Center for cluster management [default: False]")
    parser.add_argument('--control-center-next-gen', default=False, action='store_true',
                        help="Include next-generation Confluent Control Center [default: False]")
    parser.add_argument('--control-center-next-gen-release', default=CONTROL_CENTER_NEXT_GEN_RELEASE,
                        help=f"Version for next-generation Control Center [{CONTROL_CENTER_NEXT_GEN_RELEASE}]")

    parser.add_argument('-p', '--prometheus', default=False, action='store_true',
                        help="Include Prometheus and Grafana for metrics monitoring [default: False]")

    # ========== Cluster Configuration Options ==========

    parser.add_argument('--uuid', type=str, default=RANDOM_UUID,
                        help=f"Cluster UUID for KRaft mode [{RANDOM_UUID}]")

    parser.add_argument('--racks', type=int, default=1,
                        help="Number of racks for broker distribution (rack awareness) [default: 1]")
    parser.add_argument('--zookeeper-groups', type=int, default=1,
                        help="Number of ZooKeeper groups in hierarchical setup [default: 1]")

    # ========== Output Configuration ==========

    parser.add_argument('--docker-compose-file', default=DOCKER_COMPOSE_FILE,
                        help=f"Output file path for docker-compose.yml [{DOCKER_COMPOSE_FILE}]")

    parser.add_argument('--config',
                        help="Path to properties config file (command-line arguments override config file values)")

    # ========== Data Persistence Options ==========

    parser.add_argument('--persistent-volumes', default=False, action='store_true',
                        help="Enable persistent Docker volumes for data storage [default: False]")
    parser.add_argument('--volume-driver', default='local',
                        help="Docker volume driver to use [default: local]")

    # ========== Resource Management Options ==========

    parser.add_argument('--resource-profile', choices=['small', 'medium', 'large', 'none'],
                        default='none',
                        help="Resource profile for CPU and memory limits [default: none (no limits)]")
    parser.add_argument('--custom-broker-memory', type=str,
                        help="Custom memory limit for brokers (e.g., '2g', '512m')")
    parser.add_argument('--custom-broker-cpus', type=str,
                        help="Custom CPU limit for brokers (e.g., '1.0', '0.5')")

    # ========== Logging Options ==========

    parser.add_argument('-v', '--verbose', default=False, action='store_true',
                        help="Enable verbose (DEBUG) logging output")
    parser.add_argument('--log-file', type=str,
                        help="Write logs to specified file")
    parser.add_argument('--no-color', default=False, action='store_true',
                        help="Disable colored log output")

    # Parse command-line arguments
    args = parser.parse_args()

    # ========== Configure Logging ==========
    logger = setup_logging(
        verbose=args.verbose,
        log_file=args.log_file,
        color=not args.no_color
    )

    # ========== Apply OSK (Open Source Kafka) Configuration ==========
    # If --osk flag is set, override repository and container settings for Apache Kafka
    if args.osk:
        logger.info("Using Open Source Apache Kafka distribution")
        args.repository = APACHE_REPOSITORY
        args.kafka_container = APACHE_CONTAINER
        args.release = "latest"

    # ========== Load Configuration File ==========
    # If a config file is specified, load and merge its values with command-line args
    # Command-line arguments take precedence over config file values
    if args.config:
        logger.info(f"Loading configuration from: {args.config}")
        args = load_configfile(args, args.config)

    # ========== Validate Configuration ==========
    # Check for mutually exclusive or incompatible options
    logger.debug("Validating configuration...")

    # Basic mutual exclusivity checks
    validation_failed = False

    # ZooKeeper and KRaft (controllers) modes are mutually exclusive
    if args.zookeepers and args.controllers:
        logger.error("ZooKeeper and Kafka Controllers (KRaft) are mutually exclusive")
        logger.error("Use either -z/--zookeepers OR -c/--controllers, not both")
        validation_failed = True

    # Shared mode only makes sense with KRaft controllers
    if args.zookeepers and args.shared_mode:
        logger.error("ZooKeeper cannot run in shared mode with a broker")
        logger.error("Shared mode is only available with KRaft controllers")
        validation_failed = True

    # Cannot have both old and new Control Center at the same time
    if args.control_center and args.control_center_next_gen:
        logger.error("Cannot enable both standard and next-gen Control Center")
        logger.error("Choose either --control-center OR --control-center-next-gen")
        validation_failed = True

    if validation_failed:
        sys.exit(2)

    # Advanced validation
    try:
        errors, warnings = validate_configuration(args)

        # Display warnings
        if warnings:
            logger.warning("")
            logger.warning("Configuration Warnings:")
            logger.warning("-" * 60)
            for warning in warnings:
                logger.warning(f"⚠  {warning.message}")
                if warning.suggestion:
                    logger.warning(f"   💡 {warning.suggestion}")
            logger.warning("")

        # Display and handle errors
        if errors:
            logger.error("")
            logger.error("Configuration Errors:")
            logger.error("-" * 60)
            for error in errors:
                logger.error(f"✗ {error.message}")
                if error.suggestions:
                    for suggestion in error.suggestions:
                        logger.error(f"  → {suggestion}")
            logger.error("")
            sys.exit(1)

    except Exception as e:
        logger.warning(f"Validation check failed: {e}")
        logger.warning("Continuing with generation...")

    # Log configuration summary
    logger.info("=" * 60)
    logger.info("Kafka Docker Composer - Configuration Summary")
    logger.info("=" * 60)
    logger.info(f"Mode: {'KRaft' if args.controllers > 0 else 'ZooKeeper' if args.zookeepers > 0 else 'Standalone'}")
    logger.info(f"Brokers: {args.brokers}")
    if args.controllers > 0:
        logger.info(f"Controllers: {args.controllers}")
    if args.zookeepers > 0:
        logger.info(f"ZooKeepers: {args.zookeepers}")
    if args.schema_registries > 0:
        logger.info(f"Schema Registries: {args.schema_registries}")
    if args.connect_instances > 0:
        logger.info(f"Connect Instances: {args.connect_instances}")
    if args.prometheus:
        logger.info("Monitoring: Prometheus + Grafana enabled")
    if args.persistent_volumes:
        logger.info("Persistence: Docker volumes enabled")
    if args.resource_profile != 'none':
        logger.info(f"Resource Profile: {args.resource_profile}")
    logger.info("=" * 60)

    # ========== Generate Docker Compose Configuration ==========
    logger.info("Generating docker-compose configuration...")
    generator = DockerComposeGenerator(args)
    generator.generate()

    # Print success message
    logger.info(f"Successfully generated: {args.docker_compose_file}")
    logger.info("To start the cluster, run: docker compose up -d")
