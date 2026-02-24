#!/bin/bash
# Bash Script to Run EMQX MQTT Broker Docker Container
# Deploys the EMQX MQTT platform using docker-compose
# Version: 2.0
# Author: Generated for MQTT deployment
# Date: $(date +"%Y-%m-%d")

# Script configuration
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'

# Default configuration
DEFAULT_BASE_DIR="$HOME/Streaming/emqx"
BASE_DIR="${DEFAULT_BASE_DIR}"
DOCKER_COMPOSE_FILE="docker-compose.yml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="2.0"

# Flags
DRY_RUN=false
VERBOSE=false
SKIP_PULL=false
NO_LOGS=false
ACTION="start"  # start, stop, restart, status, logs

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[0;30m'  # Using black for better visibility on light backgrounds
GRAY='\033[1;30m'  # Changed to bright black (darker gray) for better visibility
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup trap for failures
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]] && [[ "$exit_code" -ne 130 ]]; then  # 130 is Ctrl+C
        echo -e "\n${RED}[ERROR] Script failed with exit code: $exit_code${NC}" >&2
        echo -e "${YELLOW}[INFO] Run with --verbose for more details${NC}" >&2
    fi
}

trap cleanup EXIT

# Logging functions
log_info() {
    echo -e "${CYAN}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[VERBOSE]${NC} $*"
    fi
}

log_dryrun() {
    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}[DRY-RUN]${NC} $*"
    fi
}

# Show help message
show_help() {
    cat << EOF
${GREEN}EMQX MQTT Broker Management Script${NC}
Version: $SCRIPT_VERSION

${CYAN}USAGE:${NC}
    $0 [OPTIONS] [ACTION]

${CYAN}ACTIONS:${NC}
    start               Start the EMQX container (default)
    stop                Stop the running container
    restart             Restart the container
    status              Show container status
    logs                Show container logs

${CYAN}OPTIONS:${NC}
    -d, --dir <path>    Base directory for installation (default: $DEFAULT_BASE_DIR)
    -n, --dry-run       Preview actions without making changes
    -v, --verbose       Enable verbose output
    --skip-pull         Skip pulling latest Docker image
    --no-logs           Don't show logs after starting
    -h, --help          Show this help message
    --version           Show script version

${CYAN}EXAMPLES:${NC}
    # Start container with default settings
    $0

    # Start with custom directory
    $0 --dir /custom/path/mqtt

    # Stop the container
    $0 stop

    # Restart and show logs
    $0 restart

    # Check status
    $0 status

    # View logs
    $0 logs

    # Dry run to preview actions
    $0 --dry-run

${CYAN}DESCRIPTION:${NC}
    This script manages the EMQX MQTT broker (Publish/Subscribe) Docker container.
    EMQX is a high-performance pub/sub broker with built-in dashboard.

    It handles deployment, starting, stopping, and monitoring of the service.

    Dashboard: http://localhost:18083 (admin/public)

${CYAN}REQUIREMENTS:${NC}
    - Docker and Docker Compose installed
    - Proper directory structure (run copy-emqx.sh first)
    - Network connectivity for pulling images

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|restart|status|logs)
                ACTION="$1"
                shift
                ;;
            -d|--dir)
                BASE_DIR="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --skip-pull)
                SKIP_PULL=true
                shift
                ;;
            --no-logs)
                NO_LOGS=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            --version)
                echo "Version $SCRIPT_VERSION"
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

# Validate prerequisites
validate_prerequisites() {
    log_verbose "Validating prerequisites..."

    # Validate base directory path
    if [[ -z "$BASE_DIR" ]]; then
        log_error "Base directory cannot be empty"
        exit 1
    fi

    log_verbose "Prerequisites validated successfully"
}

# Function to check Docker installation and status
check_docker_environment() {
    log_info "Checking Docker environment..."

    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker not found in PATH"
        log_info "Please install Docker: https://docs.docker.com/get-docker/"
        exit 1
    fi

    local docker_version=$(docker --version)
    log_success "Docker found: $docker_version"

    # Check if Docker is running
    if ! docker ps &> /dev/null; then
        log_error "Docker is installed but not running"
        log_info "Start Docker with: sudo systemctl start docker"
        exit 1
    fi
    log_success "Docker is running"

    # Check if docker-compose or docker compose is available
    if command -v docker-compose &> /dev/null; then
        log_success "Docker Compose (v1) is available"
        echo "v1"
    elif docker compose version &> /dev/null; then
        log_success "Docker Compose (v2) is available"
        echo "v2"
    else
        log_error "Docker Compose not available"
        log_info "Install with: sudo apt-get install docker-compose-plugin"
        exit 1
    fi
}

# Function to verify directory structure exists
check_directory_structure() {
    log_info "Verifying directory structure..."

    local required_dirs=(
        "$BASE_DIR"
        "$BASE_DIR/config"
        "$BASE_DIR/data"
        "$BASE_DIR/log"
    )

    local missing_dirs=()
    for dir in "${required_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            missing_dirs+=("$dir")
        fi
    done

    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_error "Missing required directories:"
        for dir in "${missing_dirs[@]}"; do
            echo -e "  ${RED}- $dir${NC}"
        done
        log_info "Run the setup script first: sudo ./copy-emqx.sh"
        exit 1
    fi

    log_success "Directory structure verified"
}

# Function to check if docker-compose.yml exists
check_docker_compose_file() {
    local compose_file="$BASE_DIR/$DOCKER_COMPOSE_FILE"

    if [[ ! -f "$compose_file" ]]; then
        log_error "docker-compose.yml not found at: $compose_file"
        log_info "Please ensure docker-compose.yml is in the emqx directory"
        return 1
    fi

    log_success "docker-compose.yml found"
    log_verbose "Compose file: $compose_file"
    return 0
}

# Execute docker-compose command
run_compose_command() {
    local compose_version=$1
    shift
    local cmd="$*"

    log_verbose "Running: docker-compose $cmd"

    if [[ "$DRY_RUN" == true ]]; then
        log_dryrun "Would execute: docker-compose $cmd"
        return 0
    fi

    cd "$BASE_DIR"

    if [[ "$compose_version" == "v2" ]]; then
        docker compose $cmd
    else
        docker-compose $cmd
    fi
}

# Function to stop existing containers
stop_containers() {
    local compose_version=$1

    log_info "Stopping containers..."

    cd "$BASE_DIR"

    local containers=""
    if [[ "$compose_version" == "v2" ]]; then
        containers=$(docker compose ps -q 2>/dev/null || true)
    else
        containers=$(docker-compose ps -q 2>/dev/null || true)
    fi

    if [[ -n "$containers" ]]; then
        run_compose_command "$compose_version" down
        log_success "Containers stopped"
    else
        log_info "No running containers to stop"
    fi
}

# Function to start the EMQX container
start_emqx_container() {
    local compose_version=$1

    log_info "Starting EMQX MQTT broker container..."

    # Pull the latest image if not skipped
    if [[ "$SKIP_PULL" == false ]]; then
        log_info "Pulling latest EMQX image..."
        run_compose_command "$compose_version" pull

        if [[ $? -ne 0 ]] && [[ "$DRY_RUN" == false ]]; then
            log_error "Failed to pull Docker image"
            exit 1
        fi
        log_success "Image pulled successfully"
    else
        log_info "Skipping image pull (--skip-pull flag)"
    fi

    # Start the container
    log_info "Starting EMQX container..."
    run_compose_command "$compose_version" up -d

    if [[ $? -ne 0 ]] && [[ "$DRY_RUN" == false ]]; then
        log_error "Failed to start container"
        log_info "Check logs with: docker-compose logs"
        exit 1
    fi
    log_success "Container started successfully"

    if [[ "$DRY_RUN" == false ]]; then
        # Wait for container to be ready
        log_info "Waiting for container to be ready..."
        sleep 5

        # Check if container is running
        local container_id=$(docker ps -q --filter "name=emqx-broker" 2>/dev/null || true)
        if [[ -n "$container_id" ]]; then
            log_success "EMQX broker is running (Container ID: $container_id)"
        else
            log_warn "Container may not be running properly"
        fi
    fi
}

# Function to show container status
show_status() {
    local compose_version=$1

    echo -e "\n${CYAN}Container Status:${NC}"
    cd "$BASE_DIR"

    if [[ "$compose_version" == "v2" ]]; then
        docker compose ps
    else
        docker-compose ps
    fi

    # Check if container is running
    local container_id=$(docker ps -q --filter "name=emqx-broker" 2>/dev/null || true)
    if [[ -n "$container_id" ]]; then
        echo ""
        log_success "EMQX broker is running"

        # Show basic stats
        echo -e "\n${CYAN}Container Stats:${NC}"
        docker stats --no-stream "$container_id"
    else
        echo ""
        log_warn "EMQX broker is not running"
    fi
}

# Function to show logs
show_logs() {
    local compose_version=$1

    log_info "Showing container logs (Ctrl+C to exit)..."
    cd "$BASE_DIR"

    if [[ "$compose_version" == "v2" ]]; then
        docker compose logs -f --tail=100
    else
        docker-compose logs -f --tail=100
    fi
}

# Function to test MQTT connectivity
test_mqtt_connectivity() {
    log_info "Testing MQTT connectivity..."

    local ports=(1883 8083 18083)
    local port_names=("MQTT" "WebSocket" "Dashboard")

    for i in "${!ports[@]}"; do
        local port="${ports[$i]}"
        local name="${port_names[$i]}"

        if timeout 2 bash -c "echo > /dev/tcp/localhost/$port" 2>/dev/null; then
            log_success "$name port $port is accessible"
        else
            log_warn "$name port $port is not accessible"
        fi
    done
}

# Function to display connection information
show_connection_info() {
    echo ""
    echo -e "${CYAN}=== Connection Information ===${NC}"
    echo -e "${WHITE}MQTT Broker:${NC}"
    echo -e "  Host: localhost"
    echo -e "  Port: 1883"
    echo -e "  Protocol: MQTT"
    echo ""
    echo -e "${WHITE}WebSocket Connection:${NC}"
    echo -e "  Host: localhost"
    echo -e "  Port: 8083"
    echo -e "  Protocol: WebSocket"
    echo ""
    echo -e "${WHITE}Dashboard UI:${NC}"
    echo -e "  URL: ${CYAN}http://localhost:18083${NC}"
    echo -e "  Username: admin"
    echo -e "  Password: public"
    echo ""
    echo -e "${WHITE}Configuration:${NC}"
    echo -e "  Config: $BASE_DIR/config/emqx.conf"
    echo -e "  Data: $BASE_DIR/data"
    echo -e "  Logs: $BASE_DIR/log"
}

# Function to display management commands
show_management_commands() {
    echo ""
    echo -e "${CYAN}=== Management Commands ===${NC}"
    echo -e "${WHITE}View logs:${NC}"
    echo -e "${GRAY}  $0 logs${NC}"
    echo -e "${GRAY}  docker-compose logs -f${NC}"
    echo ""
    echo -e "${WHITE}Container management:${NC}"
    echo -e "${GRAY}  $0 stop${NC}"
    echo -e "${GRAY}  $0 start${NC}"
    echo -e "${GRAY}  $0 restart${NC}"
    echo -e "${GRAY}  $0 status${NC}"
    echo ""
    echo -e "${WHITE}Direct Docker commands:${NC}"
    echo -e "${GRAY}  docker stats emqx-broker${NC}"
    echo -e "${GRAY}  docker exec -it emqx-broker sh${NC}"
}

# Main execution
main() {
    echo -e "${GREEN}=== EMQX MQTT Broker Deployment v$SCRIPT_VERSION ===${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Running in DRY-RUN mode - no changes will be made"
    fi

    echo -e "${YELLOW}Working directory: $BASE_DIR${NC}"
    echo -e "${YELLOW}Action: $ACTION${NC}"

    # Validate prerequisites
    validate_prerequisites

    # Check Docker environment
    compose_version=$(check_docker_environment)
    log_verbose "Using Docker Compose: $compose_version"

    # Verify directory structure
    check_directory_structure

    # Check for docker-compose.yml
    if ! check_docker_compose_file; then
        exit 1
    fi

    # Execute requested action
    case "$ACTION" in
        start)
            stop_containers "$compose_version"
            start_emqx_container "$compose_version"

            if [[ "$DRY_RUN" == false ]]; then
                test_mqtt_connectivity
                show_connection_info
                show_management_commands

                echo ""
                log_success "Deployment complete!"
                log_success "MQTT broker is running at localhost:1883"
                log_success "Dashboard at http://localhost:18083"

                if [[ "$NO_LOGS" == false ]]; then
                    echo ""
                    log_info "Showing logs (Ctrl+C to exit)..."
                    echo ""
                    log_warn "Note: If you see a Python KeyError exception at the end, it's a known"
                    log_warn "bug in docker-compose's log viewer (Python 3.12+) and can be ignored."
                    log_warn "EMQX is running correctly. Use 'docker logs -f emqx-broker' as alternative."
                    echo ""
                    sleep 2
                    show_logs "$compose_version"
                fi
            fi
            ;;
        stop)
            stop_containers "$compose_version"
            log_success "EMQX stopped"
            ;;
        restart)
            stop_containers "$compose_version"
            start_emqx_container "$compose_version"

            if [[ "$DRY_RUN" == false ]]; then
                log_success "EMQX restarted"
                test_mqtt_connectivity

                if [[ "$NO_LOGS" == false ]]; then
                    echo ""
                    log_info "Showing logs (Ctrl+C to exit)..."
                    echo ""
                    log_warn "Note: If you see a Python KeyError exception at the end, it's a known"
                    log_warn "bug in docker-compose's log viewer (Python 3.12+) and can be ignored."
                    log_warn "EMQX is running correctly. Use 'docker logs -f emqx-broker' as alternative."
                    echo ""
                    sleep 2
                    show_logs "$compose_version"
                fi
            fi
            ;;
        status)
            show_status "$compose_version"
            test_mqtt_connectivity
            ;;
        logs)
            show_logs "$compose_version"
            ;;
        *)
            log_error "Unknown action: $ACTION"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
