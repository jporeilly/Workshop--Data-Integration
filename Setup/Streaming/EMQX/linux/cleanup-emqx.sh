#!/bin/bash
# Bash Script to Clean Up/Uninstall EMQX MQTT Broker
# Removes containers, directories, and configuration files
# Version: 2.0
# Author: Generated for MQTT deployment
# Date: $(date +"%Y-%m-%d")

# Script configuration
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'

# Default configuration
DEFAULT_BASE_DIR="$HOME/Streaming/emqx"
BASE_DIR="${DEFAULT_BASE_DIR}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="2.0"

# Flags
DRY_RUN=false
VERBOSE=false
FORCE=false
KEEP_DATA=false
REMOVE_IMAGES=false

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[0;30m'  # Using black for better visibility on light backgrounds
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup trap for failures
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]] && [[ "$exit_code" -ne 130 ]]; then
        echo -e "\n${RED}[ERROR] Script failed with exit code: $exit_code${NC}" >&2
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
${GREEN}MQTT EMQX MQTT Broker Cleanup/Uninstall Script${NC}
Version: $SCRIPT_VERSION

${CYAN}USAGE:${NC}
    $0 [OPTIONS]

${CYAN}OPTIONS:${NC}
    -d, --dir <path>      Base directory to clean (default: $DEFAULT_BASE_DIR)
    -n, --dry-run         Preview what would be removed without deleting
    -v, --verbose         Enable verbose output
    -f, --force           Skip confirmation prompts
    --keep-data           Keep data directory (preserve MQTT persistence)
    --remove-images       Also remove Docker images
    -h, --help            Show this help message
    --version             Show script version

${CYAN}EXAMPLES:${NC}
    # Preview what would be removed
    sudo $0 --dry-run

    # Remove everything with confirmation
    sudo $0

    # Remove everything without prompts
    sudo $0 --force

    # Remove but keep data directory
    sudo $0 --keep-data

    # Remove custom installation
    sudo $0 --dir /custom/path/emqx

    # Full cleanup including Docker images
    sudo $0 --force --remove-images

${CYAN}DESCRIPTION:${NC}
    This script completely removes the EMQX MQTT broker installation:
    - Stops and removes Docker containers
    - Removes Docker networks
    - Deletes configuration files
    - Deletes data and log directories
    - Optionally removes Docker images

${CYAN}WARNING:${NC}
    ${RED}This will delete all MQTT data, configurations, and logs!${NC}
    ${RED}This action cannot be undone!${NC}

    Use --dry-run first to preview what will be removed.
    Use --keep-data to preserve MQTT message persistence.

EOF
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
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
            -f|--force)
                FORCE=true
                shift
                ;;
            --keep-data)
                KEEP_DATA=true
                shift
                ;;
            --remove-images)
                REMOVE_IMAGES=true
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

# Check for Docker Compose version
detect_compose_version() {
    if command -v docker-compose &> /dev/null; then
        echo "v1"
    elif docker compose version &> /dev/null; then
        echo "v2"
    else
        log_verbose "Docker Compose not found (not an error for cleanup)"
        echo "none"
    fi
}

# Ask for confirmation
confirm_action() {
    if [[ "$FORCE" == true ]] || [[ "$DRY_RUN" == true ]]; then
        return 0
    fi

    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                    ${RED}⚠️  WARNING  ⚠️${YELLOW}                        ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${RED}This will permanently delete:${NC}"
    echo -e "  • Docker containers (emqx-broker)"
    echo -e "  • Docker networks (mqtt-network)"
    echo -e "  • Configuration files: $BASE_DIR/config"
    if [[ "$KEEP_DATA" == false ]]; then
        echo -e "  • ${RED}Data directory: $BASE_DIR/data (ALL MQTT MESSAGES!)${NC}"
    else
        echo -e "  • ${GREEN}Data directory will be PRESERVED${NC}"
    fi
    echo -e "  • Log files: $BASE_DIR/log"
    echo -e "  • Base directory: $BASE_DIR"

    if [[ "$REMOVE_IMAGES" == true ]]; then
        echo -e "  • ${RED}Docker images (emqx/emqx)${NC}"
    fi

    echo ""
    echo -e "${YELLOW}This action CANNOT be undone!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        log_info "Cleanup cancelled by user"
        exit 0
    fi
}

# Stop and remove containers
stop_and_remove_containers() {
    local compose_version=$1

    log_info "Stopping and removing Docker containers..."

    cd "$BASE_DIR" 2>/dev/null || {
        log_verbose "Base directory doesn't exist or can't access: $BASE_DIR"
        return 0
    }

    if [[ ! -f "docker-compose.yml" ]]; then
        log_verbose "No docker-compose.yml found in $BASE_DIR"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would run: docker-compose down"
        else
            if [[ "$compose_version" == "v2" ]]; then
                docker compose down 2>/dev/null || log_verbose "Failed to run docker compose down (may not be running)"
            elif [[ "$compose_version" == "v1" ]]; then
                docker-compose down 2>/dev/null || log_verbose "Failed to run docker-compose down (may not be running)"
            fi
            log_success "Containers stopped and removed"
        fi
    fi

    # Remove container by name if it still exists
    local container_id=$(docker ps -aq --filter "name=emqx-broker" 2>/dev/null || true)
    if [[ -n "$container_id" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove container: $container_id"
        else
            docker rm -f "$container_id" 2>/dev/null && log_success "Removed container: $container_id"
        fi
    else
        log_verbose "No emqx-broker container found"
    fi
}

# Remove Docker network
remove_network() {
    log_info "Removing Docker network..."

    local network_id=$(docker network ls -q --filter "name=mqtt-network" 2>/dev/null || true)
    if [[ -n "$network_id" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove network: mqtt-network"
        else
            docker network rm mqtt-network 2>/dev/null && log_success "Removed network: mqtt-network" || log_verbose "Could not remove network (may be in use)"
        fi
    else
        log_verbose "No mqtt-network found"
    fi
}

# Remove Docker images
remove_images() {
    if [[ "$REMOVE_IMAGES" == false ]]; then
        log_verbose "Skipping image removal (use --remove-images to remove)"
        return 0
    fi

    log_info "Removing Docker images..."

    local images=$(docker images -q emqx/emqx 2>/dev/null || true)
    if [[ -n "$images" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove images: emqx/emqx"
        else
            docker rmi $(docker images -q emqx/emqx) 2>/dev/null && log_success "Removed Docker images" || log_warn "Could not remove some images (may be in use)"
        fi
    else
        log_verbose "No emqx/emqx images found"
    fi
}

# Remove directories
remove_directories() {
    log_info "Removing directories..."

    if [[ ! -d "$BASE_DIR" ]]; then
        log_warn "Directory does not exist: $BASE_DIR"
        return 0
    fi

    # Remove config directory
    if [[ -d "$BASE_DIR/config" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove: $BASE_DIR/config"
        else
            rm -rf "$BASE_DIR/config"
            log_success "Removed: $BASE_DIR/config"
        fi
    fi

    # Remove data directory (unless --keep-data)
    if [[ -d "$BASE_DIR/data" ]]; then
        if [[ "$KEEP_DATA" == true ]]; then
            log_warn "Keeping data directory: $BASE_DIR/data"
        else
            if [[ "$DRY_RUN" == true ]]; then
                log_dryrun "Would remove: $BASE_DIR/data"
            else
                rm -rf "$BASE_DIR/data"
                log_success "Removed: $BASE_DIR/data"
            fi
        fi
    fi

    # Remove log directory
    if [[ -d "$BASE_DIR/log" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove: $BASE_DIR/log"
        else
            rm -rf "$BASE_DIR/log"
            log_success "Removed: $BASE_DIR/log"
        fi
    fi

    # Remove transformations directory
    if [[ -d "$BASE_DIR/transformations" ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove: $BASE_DIR/transformations"
        else
            rm -rf "$BASE_DIR/transformations"
            log_success "Removed: $BASE_DIR/transformations"
        fi
    fi

    # Remove Docker files
    for file in docker-compose.yml run-docker-emqx.sh cleanup-emqx.sh README.md; do
        if [[ -f "$BASE_DIR/$file" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dryrun "Would remove: $BASE_DIR/$file"
            else
                rm -f "$BASE_DIR/$file"
                log_success "Removed: $BASE_DIR/$file"
            fi
        fi
    done

    # Remove base directory if empty or only data remains
    if [[ "$KEEP_DATA" == true ]]; then
        log_info "Keeping base directory (contains data): $BASE_DIR"
    else
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would remove: $BASE_DIR"
        else
            rmdir "$BASE_DIR" 2>/dev/null && log_success "Removed: $BASE_DIR" || log_verbose "Base directory not empty or already removed"

            # Try to remove parent directories if empty (but not ~/Streaming)
            local parent_dir=$(dirname "$BASE_DIR")
            local streaming_dir="$HOME/Streaming"

            # Only remove parent if it's not the Streaming directory
            if [[ "$parent_dir" != "$streaming_dir" ]]; then
                rmdir "$parent_dir" 2>/dev/null && log_success "Removed empty parent: $parent_dir" || log_verbose "Parent directory not empty"
            else
                log_verbose "Skipping removal of Streaming directory: $parent_dir"
            fi
        fi
    fi
}

# Display summary
show_summary() {
    echo ""
    echo -e "${GREEN}=== Cleanup Summary ===${NC}"

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${YELLOW}DRY-RUN MODE: No actual changes were made${NC}"
        echo ""
        echo "The following would be removed:"
    else
        echo "Successfully removed:"
    fi

    echo -e "  ${CYAN}✓${NC} Docker containers (emqx-broker)"
    echo -e "  ${CYAN}✓${NC} Docker network (mqtt-network)"
    echo -e "  ${CYAN}✓${NC} Configuration files"

    if [[ "$KEEP_DATA" == true ]]; then
        echo -e "  ${GREEN}✓${NC} Data preserved at: $BASE_DIR/data"
    else
        echo -e "  ${CYAN}✓${NC} Data directory"
    fi

    echo -e "  ${CYAN}✓${NC} Log files"

    if [[ "$REMOVE_IMAGES" == true ]]; then
        echo -e "  ${CYAN}✓${NC} Docker images (emqx/emqx)"
    fi

    if [[ "$KEEP_DATA" == false ]]; then
        echo -e "  ${CYAN}✓${NC} Base directory: $BASE_DIR"
    fi
}

# Main execution
main() {
    echo -e "${GREEN}=== EMQX MQTT Broker Cleanup Script v$SCRIPT_VERSION ===${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Running in DRY-RUN mode - no changes will be made"
    fi

    echo -e "${YELLOW}Target directory: $BASE_DIR${NC}"

    # Confirm action
    confirm_action

    # Detect Docker Compose version
    compose_version=$(detect_compose_version)
    log_verbose "Docker Compose: $compose_version"

    # Execute cleanup steps
    log_info "Starting cleanup process..."
    echo ""

    stop_and_remove_containers "$compose_version"
    remove_network
    remove_images
    remove_directories

    # Show summary
    show_summary

    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_info "Run without --dry-run to actually remove everything"
    else
        echo ""
        log_success "Cleanup completed successfully!"

        if [[ "$KEEP_DATA" == true ]]; then
            echo ""
            log_info "Data directory preserved at: $BASE_DIR/data"
            log_info "To remove manually: sudo rm -rf $BASE_DIR/data"
        fi
    fi
}

# Run main function with all arguments
main "$@"
