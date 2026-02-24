"""
Configuration Validator for Kafka Docker Composer

This module provides comprehensive configuration validation to catch common
mistakes, enforce best practices, and provide helpful warnings before
generating docker-compose files.

The validator checks for:
- Invalid or suboptimal cluster configurations
- Resource requirement issues
- System prerequisites
- Port conflicts
- Best practice violations

Usage:
    from validator import validate_configuration, ValidationError, ValidationWarning

    errors, warnings = validate_configuration(args)

    # Handle errors (fatal - prevent generation)
    if errors:
        for error in errors:
            print(f"ERROR: {error.message}")
            for suggestion in error.suggestions:
                print(f"  → {suggestion}")
        sys.exit(1)

    # Handle warnings (non-fatal - inform user)
    if warnings:
        for warning in warnings:
            print(f"WARNING: {warning.message}")
            if warning.suggestion:
                print(f"  💡 {warning.suggestion}")

Validation Categories:
    1. Broker Count - Ensures adequate fault tolerance
    2. Controller Count - Validates KRaft quorum configuration
    3. Replication - Checks replication factor feasibility
    4. System Requirements - Verifies Docker and resources
    5. Resource Profiles - Validates profile appropriateness
"""

import shutil
from typing import List, Tuple
from logger import get_logger

# Get module logger for validation logging
logger = get_logger(__name__)


class ValidationError(Exception):
    """
    Exception raised for fatal configuration validation errors.

    Validation errors prevent docker-compose generation and should be
    fixed before proceeding. They typically indicate:
    - Invalid parameter values (e.g., brokers < 1)
    - Impossible configurations (e.g., even controller count in quorum)
    - Missing prerequisites (e.g., Docker not installed)

    Attributes:
        message (str): Human-readable error description
        suggestions (List[str]): List of actionable suggestions to fix the error

    Example:
        raise ValidationError(
            "At least 1 broker is required",
            suggestions=["Use -b/--brokers with a value >= 1"]
        )
    """

    def __init__(self, message: str, suggestions: List[str] = None):
        """
        Initialize a validation error with message and optional suggestions.

        Args:
            message: Description of the validation error
            suggestions: List of suggestions to resolve the error
        """
        self.message = message
        self.suggestions = suggestions or []
        super().__init__(self.message)


class ValidationWarning:
    """
    Represents a non-fatal configuration warning.

    Warnings inform users about suboptimal configurations that may work
    but are not recommended. They include:
    - Insufficient fault tolerance (e.g., single broker)
    - Suboptimal configurations (e.g., even controller count)
    - High resource usage warnings
    - Best practice violations

    Unlike ValidationErrors, warnings do not prevent generation.

    Attributes:
        message (str): Human-readable warning description
        suggestion (str): Optional suggestion to improve the configuration

    Example:
        ValidationWarning(
            "Single broker configuration - no fault tolerance",
            "Consider using at least 3 brokers for production"
        )
    """

    def __init__(self, message: str, suggestion: str = None):
        """
        Initialize a validation warning with message and optional suggestion.

        Args:
            message: Description of the configuration issue
            suggestion: Recommendation to improve the configuration
        """
        self.message = message
        self.suggestion = suggestion


def validate_configuration(args) -> Tuple[List[ValidationError], List[ValidationWarning]]:
    """
    Validate the complete configuration and return all errors and warnings.

    This is the main validation entry point that orchestrates all validation
    checks. It collects errors (fatal issues) and warnings (non-fatal issues)
    from various validation functions.

    Validation Flow:
        1. Broker count validation (always performed)
        2. Controller count validation (only for KRaft mode)
        3. Replication settings validation
        4. System requirements check
        5. Resource profile validation (if profile is set)

    Args:
        args: Parsed command-line arguments containing cluster configuration

    Returns:
        Tuple of (errors, warnings) lists:
            - errors: List of ValidationError objects (fatal - prevent generation)
            - warnings: List of ValidationWarning objects (non-fatal - inform user)

    Example:
        errors, warnings = validate_configuration(args)
        if errors:
            for error in errors:
                print(f"ERROR: {error.message}")
            sys.exit(1)
    """
    # Initialize empty lists to collect all validation results
    errors = []
    warnings = []

    # ========== Validate Broker Count ==========
    # Always validate broker count as it's required for any cluster
    # Checks: minimum count, fault tolerance recommendations
    errors_list, warnings_list = validate_broker_count(args)
    errors.extend(errors_list)
    warnings.extend(warnings_list)

    # ========== Validate Controller Count (KRaft Mode) ==========
    # Only validate if controllers are configured (KRaft mode)
    # Checks: quorum requirements, odd number recommendation
    if args.controllers > 0:
        errors_list, warnings_list = validate_controller_count(args)
        errors.extend(errors_list)
        warnings.extend(warnings_list)

    # ========== Validate Replication Settings ==========
    # Check if the cluster can support desired replication factor
    # Considers both broker count and shared mode configuration
    errors_list, warnings_list = validate_replication(args)
    errors.extend(errors_list)
    warnings.extend(warnings_list)

    # ========== Validate System Requirements ==========
    # Check for Docker availability and estimate memory usage
    # These are always warnings (not fatal errors)
    warnings_list = validate_system_requirements(args)
    warnings.extend(warnings_list)

    # ========== Validate Resource Profile ==========
    # Only validate if a resource profile is specified
    # Checks if profile is appropriate for cluster size
    if args.resource_profile != 'none':
        warnings_list = validate_resource_profile(args)
        warnings.extend(warnings_list)

    # Return complete validation results
    return errors, warnings


def validate_broker_count(args) -> Tuple[List[ValidationError], List[ValidationWarning]]:
    """
    Validate broker count configuration for fault tolerance and resource feasibility.

    This function checks if the broker count is valid and provides recommendations
    for production-ready configurations. Kafka brokers handle all data storage
    and serving for the cluster.

    Validation Rules:
        - FATAL: Less than 1 broker (cluster cannot function)
        - WARNING: 1 broker (no fault tolerance, data loss if it fails)
        - WARNING: 2 brokers (limited fault tolerance, no quorum if one fails)
        - WARNING: More than 10 brokers (high resource requirements)

    Args:
        args: Configuration arguments with 'brokers' attribute

    Returns:
        Tuple of (errors, warnings) lists for broker count validation

    Note:
        3 brokers is the recommended minimum for production deployments,
        providing fault tolerance and allowing one broker to fail without
        data loss (assuming replication factor of 3).
    """
    errors = []
    warnings = []

    # ========== Fatal Error: No Brokers ==========
    # At least one broker is required for any Kafka cluster
    # Without brokers, there's nowhere to store or serve data
    if args.brokers < 1:
        errors.append(ValidationError(
            "At least 1 broker is required",
            suggestions=["Use -b/--brokers with a value >= 1"]
        ))

    # ========== Warning: Single Broker ==========
    # One broker means no fault tolerance
    # If it fails or is restarted, the entire cluster is unavailable
    # Suitable only for development/testing
    if args.brokers == 1:
        warnings.append(ValidationWarning(
            "Single broker configuration - no fault tolerance",
            "Consider using at least 3 brokers for production"
        ))

    # ========== Warning: Two Brokers ==========
    # Two brokers provide minimal redundancy but can't form a quorum
    # If one fails, the cluster may become unstable
    # With replication factor 2, losing one broker means data is not replicated
    if args.brokers == 2:
        warnings.append(ValidationWarning(
            "2 brokers provide limited fault tolerance",
            "Use 3 or more brokers for better reliability"
        ))

    # ========== Warning: Large Cluster ==========
    # More than 10 brokers significantly increases:
    # - Memory requirements (~512MB+ per broker)
    # - CPU usage (especially for replication)
    # - Network bandwidth (broker-to-broker communication)
    if args.brokers > 10:
        warnings.append(ValidationWarning(
            f"{args.brokers} brokers may require significant system resources",
            "Ensure sufficient CPU and memory are available"
        ))

    return errors, warnings


def validate_controller_count(args) -> Tuple[List[ValidationError], List[ValidationWarning]]:
    """
    Validate controller count for KRaft mode quorum requirements.

    KRaft (Kafka Raft) is the new consensus protocol that replaces ZooKeeper.
    Controllers form a Raft quorum to manage cluster metadata and leader elections.

    Quorum Mathematics:
        - Quorum size = (N / 2) + 1
        - For 3 controllers: quorum = 2 (can tolerate 1 failure)
        - For 5 controllers: quorum = 3 (can tolerate 2 failures)
        - Even numbers waste resources (4 controllers = same fault tolerance as 3)

    Validation Rules:
        - FATAL: Less than 1 controller (KRaft mode cannot function)
        - WARNING: 1 controller (metadata not fault-tolerant)
        - WARNING: 2 controllers (cannot form quorum if one fails)
        - WARNING: Even number > 2 (suboptimal quorum behavior)

    Args:
        args: Configuration arguments with 'controllers' attribute

    Returns:
        Tuple of (errors, warnings) lists for controller count validation

    Note:
        3 controllers is recommended for production. This provides fault tolerance
        while maintaining a quorum if one controller fails. More than 3 is only
        needed for very large deployments requiring higher metadata availability.
    """
    errors = []
    warnings = []

    # ========== Fatal Error: No Controllers ==========
    # KRaft mode requires at least one controller to manage cluster metadata
    # Without controllers, there's no coordination for leader election,
    # partition assignment, or configuration management
    if args.controllers < 1:
        errors.append(ValidationError(
            "KRaft mode requires at least 1 controller",
            suggestions=["Use -c/--controllers with a value >= 1"]
        ))

    # ========== Warning: Single Controller ==========
    # One controller means no fault tolerance for metadata
    # If it fails, the cluster loses coordination ability
    # Suitable only for development/testing environments
    if args.controllers == 1:
        warnings.append(ValidationWarning(
            "Single controller - metadata not fault-tolerant",
            "Use 3 controllers for production deployments"
        ))

    # ========== Warning: Two Controllers ==========
    # Two controllers is problematic for quorum:
    # - Quorum requires 2 out of 2 controllers
    # - If one fails, cannot achieve quorum (need 2, only have 1)
    # - Effectively worse than having 1 controller
    # This is a common misconfiguration
    if args.controllers == 2:
        warnings.append(ValidationWarning(
            "2 controllers cannot form a quorum if one fails",
            "Use odd numbers (1, 3, 5) for controller count"
        ))

    # ========== Warning: Even Number of Controllers ==========
    # Even numbers are inefficient for Raft quorum:
    # - 4 controllers: quorum = 3, tolerates 1 failure (same as 3 controllers)
    # - 6 controllers: quorum = 4, tolerates 2 failures (same as 5 controllers)
    # The extra controller provides no additional fault tolerance
    if args.controllers % 2 == 0 and args.controllers > 2:
        warnings.append(ValidationWarning(
            f"{args.controllers} is an even number - not recommended",
            "Use odd numbers (3, 5, 7) for optimal quorum behavior"
        ))

    return errors, warnings


def validate_replication(args) -> Tuple[List[ValidationError], List[ValidationWarning]]:
    """
    Validate replication factor settings for data redundancy.

    Replication factor determines how many copies of each partition exist
    across the cluster. Higher replication provides better fault tolerance
    but increases storage and network requirements.

    Replication Logic:
        - Default replication factor: min(3, available_nodes)
        - Available nodes = brokers (or brokers + controllers in shared mode)
        - Internal topics (__consumer_offsets, __transaction_state) also replicated

    Validation Rules:
        - WARNING: Replication factor < 3 (reduced fault tolerance)
        - WARNING: Less than 3 brokers in dedicated mode (limits redundancy)

    Args:
        args: Configuration arguments with 'brokers', 'shared_mode', 'controllers'

    Returns:
        Tuple of (errors, warnings) lists for replication validation

    Note:
        Replication factor of 3 is recommended for production. This allows:
        - 2 failures without data loss (assuming min.insync.replicas=2)
        - One replica for maintenance while maintaining redundancy
        - Good balance between availability and resource usage
    """
    errors = []
    warnings = []

    # ========== Calculate Total Available Nodes ==========
    # In dedicated mode: only brokers store data
    # In shared mode: controllers can also store data
    total_nodes = args.brokers
    if args.shared_mode:
        # Shared mode allows controllers to also act as brokers
        # This increases the number of nodes available for replication
        total_nodes += args.controllers

    # ========== Determine Effective Replication Factor ==========
    # The cluster will use the minimum of:
    # - Desired replication (3 for fault tolerance)
    # - Available nodes (can't replicate to more nodes than exist)
    replication_factor = min(3, total_nodes)

    # ========== Warning: Suboptimal Replication Factor ==========
    # If we have enough nodes for RF=3 but won't achieve it,
    # there may be a configuration issue
    # This should rarely trigger with current logic
    if replication_factor < 3 and total_nodes >= 3:
        warnings.append(ValidationWarning(
            "Replication factor will be less than 3",
            "This reduces fault tolerance"
        ))

    # ========== Warning: Insufficient Brokers for Replication ==========
    # In dedicated mode (controllers don't store data):
    # - Less than 3 brokers means replication factor < 3
    # - Internal topics (__consumer_offsets, __transaction_state) will have
    #   reduced redundancy, increasing risk of data loss
    # - User topics will also be limited to RF < 3
    if args.brokers < 3 and not args.shared_mode:
        warnings.append(ValidationWarning(
            "Less than 3 brokers limits replication factor",
            "Internal topics will have reduced redundancy"
        ))

    return errors, warnings


def validate_system_requirements(args) -> List[ValidationWarning]:
    """
    Validate that the system has Docker installed and sufficient resources.

    This function performs system-level checks to ensure the environment
    can successfully run the generated docker-compose configuration.

    Checks Performed:
        1. Docker binary availability in PATH
        2. Docker Compose availability (standalone or plugin)
        3. Memory requirements estimation

    Args:
        args: Configuration arguments for resource estimation

    Returns:
        List of ValidationWarning objects (never returns errors - all issues
        are warnings since we can't definitively check resource availability)

    Note:
        These are warnings rather than errors because:
        - Docker might be installed but not in PATH
        - Memory might be sufficient despite our conservative estimates
        - User might allocate more resources to Docker after seeing warnings
    """
    warnings = []

    # ========== Check Docker Availability ==========
    # shutil.which() searches PATH for the executable
    # Returns None if not found
    if not shutil.which('docker'):
        warnings.append(ValidationWarning(
            "Docker command not found in PATH",
            "Ensure Docker is installed and accessible"
        ))

    # ========== Check Docker Compose Availability ==========
    # Two ways to use Docker Compose:
    # 1. Standalone: docker-compose command (older installations)
    # 2. Plugin: docker compose command (newer installations)
    # Check for either variant
    has_compose = shutil.which('docker-compose') or shutil.which('docker')
    if not has_compose:
        warnings.append(ValidationWarning(
            "Docker Compose not found in PATH",
            "Install Docker Compose or use Docker with compose plugin"
        ))

    # ========== Estimate and Validate Memory Requirements ==========
    # Calculate estimated memory based on configured services
    # This is a conservative estimate assuming default heap sizes
    estimated_memory_mb = estimate_memory_usage(args)

    # Warn if estimated usage exceeds 8GB
    # 8GB is a reasonable threshold for typical developer machines
    # Production deployments should have significantly more
    if estimated_memory_mb > 8192:
        warnings.append(ValidationWarning(
            f"Estimated memory usage: ~{estimated_memory_mb}MB",
            "Ensure Docker has sufficient memory allocated"
        ))

    return warnings


def validate_resource_profile(args) -> List[ValidationWarning]:
    """
    Validate resource profile configuration and appropriateness for cluster size.

    Resource profiles define CPU and memory limits for all services in the cluster.
    This function checks if the selected profile is appropriate for the cluster size.

    Available Profiles:
        - small: Development/testing (512MB broker memory, 0.5 CPU)
        - medium: Small production (2GB broker memory, 1.0 CPU)
        - large: Large production (4GB broker memory, 2.0 CPU)
        - none: No resource limits (default)

    Validation Rules:
        - WARNING: Unknown profile name
        - WARNING: Small profile with large cluster (may be underpowered)
        - WARNING: Large profile with single broker (wasteful)

    Args:
        args: Configuration arguments with 'resource_profile' and 'brokers'

    Returns:
        List of ValidationWarning objects for resource profile validation

    Note:
        Profile selection should balance resource efficiency with performance:
        - Small clusters (1-3 brokers): small or medium profile
        - Medium clusters (4-6 brokers): medium profile
        - Large clusters (7+ brokers): medium or large profile
    """
    warnings = []

    # Import resource profiles from constants module
    # Done here to avoid circular imports
    from constants import RESOURCE_PROFILES

    # ========== Lookup Resource Profile ==========
    # Get the profile configuration, returns empty dict if not found
    profile = RESOURCE_PROFILES.get(args.resource_profile, {})

    # ========== Warning: Unknown Profile ==========
    # If profile doesn't exist in RESOURCE_PROFILES, no limits will be applied
    # The system will fall back to Docker defaults (no resource limits)
    if not profile:
        warnings.append(ValidationWarning(
            f"Unknown resource profile: {args.resource_profile}",
            "Using default (no limits)"
        ))
        # Early return since we can't validate an unknown profile
        return warnings

    # ========== Warning: Small Profile with Large Cluster ==========
    # Small profile allocates limited resources per broker (512MB, 0.5 CPU)
    # With many brokers, this may cause:
    # - Garbage collection pressure
    # - Slow replication
    # - Message processing delays
    if args.resource_profile == 'small' and args.brokers > 3:
        warnings.append(ValidationWarning(
            f"'small' profile with {args.brokers} brokers may be underpowered",
            "Consider using 'medium' or 'large' profile"
        ))

    # ========== Warning: Large Profile with Single Broker ==========
    # Large profile allocates 4GB memory and 2 CPUs per broker
    # For a single broker in development/testing, this is usually overkill
    # and wastes system resources that could be used elsewhere
    if args.resource_profile == 'large' and args.brokers == 1:
        warnings.append(ValidationWarning(
            "'large' profile for single broker may be excessive",
            "Consider using 'small' or 'medium' profile"
        ))

    return warnings


def estimate_memory_usage(args) -> int:
    """
    Estimate total memory usage in MB for the entire cluster.

    This function calculates a conservative estimate of memory requirements
    based on the configured services. The estimates are based on:
    - Minimum heap sizes for Java services
    - Typical operating overhead
    - Default configuration values

    Memory Estimates per Component:
        - Kafka Broker: 512MB (256MB heap + OS overhead)
        - Controller: 256MB (128MB heap + OS overhead)
        - ZooKeeper: 256MB (128MB heap + OS overhead)
        - Schema Registry: 256MB (128MB heap + OS overhead)
        - Kafka Connect: 512MB (256MB heap + OS overhead)
        - ksqlDB Server: 1024MB (512MB heap + OS overhead)
        - Control Center: 2048MB (1GB heap + significant overhead)
        - Prometheus: 512MB (metrics storage + processing)
        - Grafana: 256MB (dashboard rendering)

    Args:
        args: Configuration arguments with service counts

    Returns:
        int: Estimated total memory usage in MB

    Note:
        This is a conservative minimum estimate. Actual usage may be higher
        under load, especially for:
        - High-throughput brokers (may need 2-4GB+)
        - ksqlDB with complex queries (may need 2-4GB+)
        - Control Center with many clusters (may need 3-4GB+)
    """
    # Initialize memory counter
    memory_mb = 0

    # ========== Kafka Brokers ==========
    # Brokers handle all data storage and serving
    # Minimum: 512MB each (256MB heap + 256MB for page cache and overhead)
    # Production: typically 2-8GB depending on throughput
    memory_mb += args.brokers * 512

    # ========== KRaft Controllers ==========
    # Controllers manage cluster metadata in KRaft mode
    # Lighter weight than brokers since they don't handle data
    # 256MB is sufficient for metadata management
    memory_mb += args.controllers * 256

    # ========== ZooKeeper Nodes ==========
    # ZooKeeper stores cluster metadata (legacy mode)
    # Metadata is typically small, 256MB is sufficient
    memory_mb += args.zookeepers * 256

    # ========== Schema Registry ==========
    # Stores and serves Avro/JSON/Protobuf schemas
    # Schema data is typically small, 256MB is sufficient
    memory_mb += args.schema_registries * 256

    # ========== Kafka Connect Workers ==========
    # Runs connectors for data integration
    # Needs more memory than Schema Registry due to connector overhead
    # 512MB allows running 2-3 connectors per worker
    memory_mb += args.connect_instances * 512

    # ========== ksqlDB Servers ==========
    # Stream processing with SQL queries
    # Memory-intensive due to state stores and query processing
    # 1GB minimum, production workloads often need 2-4GB+
    memory_mb += args.ksqldb_instances * 1024

    # ========== Confluent Control Center ==========
    # Web UI for cluster management and monitoring
    # Very memory-intensive due to metrics collection and UI
    # 2GB minimum, may need 3-4GB for large clusters
    if args.control_center or args.control_center_next_gen:
        memory_mb += 2048

    # ========== Prometheus ==========
    # Metrics collection and time-series storage
    # Memory usage grows with number of services and retention period
    # 512MB is reasonable for development, production may need 1-2GB+
    if args.prometheus:
        memory_mb += 512

    # ========== Grafana ==========
    # Dashboard visualization for metrics
    # Relatively lightweight, mainly rendering dashboards
    # 256MB is sufficient for most use cases
    if args.prometheus:
        memory_mb += 256

    return memory_mb


def check_port_conflicts(args) -> List[ValidationWarning]:
    """
    Check for potential port conflicts in the configuration.

    This function identifies potential port conflicts within the generated
    configuration. It checks for:
    - Duplicate port assignments within the cluster
    - Common ports that may be in use by other services

    NOTE: This is a static analysis - it only checks the configuration,
    not the actual system. A full implementation would use socket binding
    or platform-specific tools to check if ports are actually in use.

    Port Allocations:
        - Broker external ports: 9091, 9092, 9093, ... (9091 + broker_id)
        - Control Center: 9021
        - Prometheus: 9090
        - Grafana: 3000
        - Schema Registry: 8081
        - Kafka Connect: 8083, 8084, ...

    Args:
        args: Configuration arguments with service counts

    Returns:
        List of ValidationWarning objects for port conflict issues

    Note:
        To check for actual port usage on the system, users can:
        - Linux/Mac: netstat -tuln | grep <port>
        - Windows: netstat -ano | findstr <port>
        - Docker: docker ps --format "{{.Ports}}" to see used ports
    """
    warnings = []

    # This is a simplified check - a full implementation would
    # actually check if ports are in use on the system using:
    # - socket.socket().bind() attempt
    # - platform-specific tools (netstat, ss, lsof)
    # For now, we just track ports in our config to avoid duplicates

    # ========== Track Used Ports ==========
    # Set to store all ports we'll use in the configuration
    # This helps detect internal conflicts
    used_ports = set()

    # ========== Check Broker External Ports ==========
    # Each broker gets an external port: 9091, 9092, 9093, etc.
    # These are mapped to the container's internal port 19094/19095/19096
    for i in range(args.brokers):
        port = 9091 + i
        # Check if this port is already in our set (shouldn't happen with current logic)
        if port in used_ports:
            warnings.append(ValidationWarning(
                f"Port {port} may be in use",
                "Check for existing services using this port"
            ))
        # Add to our tracking set
        used_ports.add(port)

    # ========== Check Standard Service Ports ==========
    # Map of well-known ports used by optional services
    # These are common ports that may conflict with existing services
    standard_ports = {
        9021: "Control Center",      # Confluent Control Center UI
        9090: "Prometheus",            # Prometheus metrics server
        3000: "Grafana",               # Grafana dashboard UI
        8081: "Schema Registry",       # Schema Registry REST API
        8083: "Kafka Connect"          # Kafka Connect REST API (first instance)
    }

    # Check each standard port for conflicts
    for port, service in standard_ports.items():
        if port in used_ports:
            # Port was already allocated to a broker - conflict!
            warnings.append(ValidationWarning(
                f"Port {port} ({service}) may conflict",
                "Ensure no other services are using this port"
            ))
        # Note: We don't add standard_ports to used_ports because
        # this is a simplified implementation that only checks broker conflicts

    return warnings
