#!/bin/bash
# Bash Script to Create MQTT Directory Structure
# Creates the required directory structure for Cedalo Mosquitto Docker container
# Version: 2.0
# Author: Generated for MQTT deployment
# Date: $(date +"%Y-%m-%d")

# Script configuration
set -euo pipefail  # Exit on error, undefined vars, pipe failures
IFS=$'\n\t'

# Default configuration
DEFAULT_BASE_DIR="/opt/Streaming/MQTT/mosquitto"
BASE_DIR="${DEFAULT_BASE_DIR}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_VERSION="2.0"

# Flags
DRY_RUN=false
VERBOSE=false
FORCE_OVERWRITE=false
SKIP_TRANSFORMATIONS=false

# Color codes for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Cleanup trap for failures
cleanup() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
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
${GREEN}MQTT Mosquitto Directory Setup Script${NC}
Version: $SCRIPT_VERSION

${CYAN}USAGE:${NC}
    $0 [OPTIONS]

${CYAN}OPTIONS:${NC}
    -d, --dir <path>        Base directory for installation (default: $DEFAULT_BASE_DIR)
    -n, --dry-run           Preview actions without making changes
    -v, --verbose           Enable verbose output
    -f, --force             Force overwrite existing files
    -s, --skip-transforms   Skip copying transformations folder
    -h, --help              Show this help message
    --version               Show script version

${CYAN}EXAMPLES:${NC}
    # Default installation
    sudo $0

    # Custom directory
    sudo $0 --dir /custom/path/mosquitto

    # Dry run to preview changes
    sudo $0 --dry-run

    # Verbose mode with custom directory
    sudo $0 -v -d /custom/path/mosquitto

${CYAN}DESCRIPTION:${NC}
    This script creates the directory structure and configuration files
    needed for running Cedalo Mosquitto MQTT broker in Docker.

    It will create:
    - Directory structure (config, data, log)
    - Mosquitto configuration file
    - Password and ACL templates
    - README documentation
    - Copy Docker deployment files

${CYAN}REQUIREMENTS:${NC}
    - Root/sudo privileges (for system directories)
    - Docker and Docker Compose installed (for deployment)

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
                FORCE_OVERWRITE=true
                shift
                ;;
            -s|--skip-transforms)
                SKIP_TRANSFORMATIONS=true
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

    # Check if running as root (only if not in user's home directory)
    if [[ ! "$BASE_DIR" =~ ^$HOME ]]; then
        if [[ $EUID -ne 0 ]] && [[ "$DRY_RUN" == false ]]; then
            log_error "Root privileges required for directory: $BASE_DIR"
            log_info "Please run with sudo or choose a directory in your home folder"
            exit 1
        fi
    fi

    # Validate base directory path
    if [[ -z "$BASE_DIR" ]]; then
        log_error "Base directory cannot be empty"
        exit 1
    fi

    # Check if parent directory exists (for non-dry-run)
    local parent_dir=$(dirname "$BASE_DIR")
    if [[ "$DRY_RUN" == false ]] && [[ ! -d "$parent_dir" ]]; then
        log_error "Parent directory does not exist: $parent_dir"
        exit 1
    fi

    log_verbose "Prerequisites validated successfully"
}

# Function to create directory structure with proper permissions
create_mqtt_directory_structure() {
    local base_path=$1

    # Define all required directories
    local directories=(
        "$base_path"
        "$base_path/config"
        "$base_path/data"
        "$base_path/log"
    )

    log_info "Creating directory structure..."

    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            if [[ "$DRY_RUN" == true ]]; then
                log_dryrun "Would create: $dir"
            else
                mkdir -p "$dir"
                log_success "Created: $dir"
                chmod 755 "$dir"
                log_verbose "Set permissions 755 on: $dir"
            fi
        else
            log_warn "Already exists: $dir"
        fi
    done
}

# Function to create basic Mosquitto configuration file
create_mosquitto_config_file() {
    local config_path=$1
    local config_file="$config_path/mosquitto.conf"

    local config_content='# Mosquitto Configuration File
# Basic configuration for Cedalo MQTT broker
# Generated by setup script

# Network settings
listener 1883
listener 9001
protocol websockets

# Security settings
allow_anonymous true
# Uncomment and configure for authentication
# password_file /mosquitto/config/passwd
# acl_file /mosquitto/config/acl

# Logging configuration
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true

# Persistence settings
persistence true
persistence_location /mosquitto/data/
autosave_interval 1800

# Connection settings
max_connections 1000
max_keepalive 300
keepalive_interval 60

# Queue settings
max_queued_messages 1000
message_size_limit 0

# Client settings
client_id_prefixes
max_inflight_messages 20
max_queued_messages 1000
'

    if [[ ! -f "$config_file" ]] || [[ "$FORCE_OVERWRITE" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would create: $config_file"
        else
            echo "$config_content" > "$config_file"
            log_success "Created Mosquitto configuration: $config_file"
            chmod 644 "$config_file"
        fi
    else
        log_warn "Configuration file already exists: $config_file (use --force to overwrite)"
    fi
}

# Function to create a sample password file template
create_password_file_template() {
    local config_path=$1
    local password_file="$config_path/passwd.template"

    local password_template='# Mosquitto Password File Template
# To use authentication:
# 1. Uncomment the password_file line in mosquitto.conf
# 2. Add users with: mosquitto_passwd -c /mosquitto/config/passwd username
# 3. Or manually add users in format: username:password_hash
#
# Example:
# admin:$6$randomsalt$hashedpassword
# user1:$6$randomsalt$hashedpassword
'

    if [[ ! -f "$password_file" ]] || [[ "$FORCE_OVERWRITE" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would create: $password_file"
        else
            echo "$password_template" > "$password_file"
            log_success "Created password file template: $password_file"
            chmod 644 "$password_file"
        fi
    else
        log_verbose "Password template already exists: $password_file"
    fi
}

# Function to create ACL file template
create_acl_file_template() {
    local config_path=$1
    local acl_file="$config_path/acl.template"

    local acl_template='# Mosquitto ACL File Template
# Access Control List for MQTT topics
# Format: user username
#         topic [read|write|readwrite] topic
#
# Example:
# user admin
# topic readwrite #
#
# user sensor1
# topic write sensors/temperature/+
# topic read commands/sensor1
#
# pattern read sensors/%u/+
# pattern write sensors/%u/status
'

    if [[ ! -f "$acl_file" ]] || [[ "$FORCE_OVERWRITE" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would create: $acl_file"
        else
            echo "$acl_template" > "$acl_file"
            log_success "Created ACL file template: $acl_file"
            chmod 644 "$acl_file"
        fi
    else
        log_verbose "ACL template already exists: $acl_file"
    fi
}

# Function to find transformations folder
find_transformations_folder() {
    local possible_paths=(
        "$HOME/Workshop--Data-Integration/Labs/Module 7 - Use Cases/Streaming Data/MQTT/transformations"
        "/home/pentaho/Workshop--Data-Integration/Labs/Module 7 - Use Cases/Streaming Data/MQTT/transformations"
        "$SCRIPT_DIR/../../Labs/Module 7 - Use Cases/Streaming Data/MQTT/transformations"
    )

    for path in "${possible_paths[@]}"; do
        if [[ -d "$path" ]]; then
            echo "$path"
            return 0
        fi
    done

    return 1
}

# Function to copy transformations folder
copy_transformations_folder() {
    local target_path=$1
    local target_folder="$target_path/transformations"

    if [[ "$SKIP_TRANSFORMATIONS" == true ]]; then
        log_info "Skipping transformations copy (--skip-transforms flag)"
        return 0
    fi

    log_info "Looking for transformations folder..."

    local source_path
    if source_path=$(find_transformations_folder); then
        log_verbose "Found transformations at: $source_path"

        if [[ -d "$target_folder" ]] && [[ "$FORCE_OVERWRITE" == false ]]; then
            log_warn "Transformations folder already exists at: $target_folder"
        else
            if [[ "$DRY_RUN" == true ]]; then
                log_dryrun "Would copy: $source_path -> $target_folder"
            else
                cp -r "$source_path" "$target_folder"
                log_success "Copied transformations folder to: $target_folder"
            fi
        fi
    else
        log_warn "Source transformations folder not found"
        log_info "Checked common locations. Skipping transformations copy."
    fi
}

# Function to copy Docker files
copy_docker_files() {
    local target_path=$1

    log_info "Copying Docker deployment files..."

    local files_to_copy=(
        "run-docker-mosquitto.sh"
        "docker-compose.yml"
    )

    for file in "${files_to_copy[@]}"; do
        local source_path="$SCRIPT_DIR/$file"
        local target_file="$target_path/$file"

        if [[ -f "$source_path" ]]; then
            if [[ -f "$target_file" ]] && [[ "$FORCE_OVERWRITE" == false ]]; then
                log_warn "$file already exists at target location"
            else
                if [[ "$DRY_RUN" == true ]]; then
                    log_dryrun "Would copy: $file -> $target_file"
                else
                    cp "$source_path" "$target_file"
                    log_success "Copied $file to: $target_file"

                    # Make shell scripts executable
                    if [[ "$file" == *.sh ]]; then
                        chmod +x "$target_file"
                        log_verbose "Made executable: $target_file"
                    fi
                fi
            fi
        else
            log_error "$file not found in: $source_path"
            log_info "Please ensure $file is in the same directory as this script"
        fi
    done
}

# Function to create a README file
create_readme_file() {
    local base_path=$1
    local readme_file="$base_path/README.md"

    local readme_content="# MQTT Cedalo Mosquitto Docker Setup

This directory contains the configuration and data files for the Cedalo Mosquitto MQTT broker.

## Directory Structure

- **config/**: Configuration files for Mosquitto
  - mosquitto.conf: Main configuration file
  - passwd.template: Password file template for authentication
  - acl.template: Access Control List template
- **data/**: Persistent data storage for MQTT messages
- **log/**: Log files from the Mosquitto broker
- **transformations/**: Data transformation scripts and configurations
- **run-docker-mosquitto.sh**: Docker deployment script
- **docker-compose.yml**: Docker Compose configuration

## Usage

1. Deploy the container: \`./run-docker-mosquitto.sh\`
2. Access Management Center: http://localhost:8088
   - Username: cedalo
   - Password: password

## Configuration

Edit the \`config/mosquitto.conf\` file to customize:
- Authentication settings
- Logging levels
- Connection limits
- Security options

## Transformations

The transformations folder contains:
- Data transformation scripts
- Configuration files for data processing
- Sample transformation examples

## Security

For production use:
1. Enable authentication by uncommenting password_file in mosquitto.conf
2. Create user accounts with mosquitto_passwd
3. Configure ACL rules for topic access control
4. Consider using TLS/SSL certificates
5. Change default Management Center credentials

## Ports

- **1883**: MQTT protocol port
- **9001**: WebSocket port for web clients
- **8088**: Management Center UI
- **8883**: MQTT over TLS (optional)

## Management Commands

\`\`\`bash
# View logs
docker-compose logs -f

# Stop/start container
docker-compose stop
docker-compose start

# Restart container
docker-compose restart

# Remove container
docker-compose down
\`\`\`

## Created: $(date +"%Y-%m-%d %H:%M:%S")
## Installation Path: $base_path
"

    if [[ ! -f "$readme_file" ]] || [[ "$FORCE_OVERWRITE" == true ]]; then
        if [[ "$DRY_RUN" == true ]]; then
            log_dryrun "Would create: $readme_file"
        else
            echo "$readme_content" > "$readme_file"
            log_success "Created README file: $readme_file"
            chmod 644 "$readme_file"
        fi
    else
        log_verbose "README already exists: $readme_file"
    fi
}

# Display summary
display_summary() {
    echo ""
    echo -e "${GREEN}=== Directory Structure ===${NC}"
    echo -e "${WHITE}Base Directory: $BASE_DIR${NC}"
    echo -e "${CYAN}|-- config/${NC}"
    echo -e "${WHITE}|   |-- mosquitto.conf${NC}"
    echo -e "${WHITE}|   |-- passwd.template${NC}"
    echo -e "${WHITE}|   +-- acl.template${NC}"
    echo -e "${CYAN}|-- data/${NC}"
    echo -e "${CYAN}|-- log/${NC}"
    echo -e "${CYAN}|-- transformations/${NC}"
    echo -e "${WHITE}|-- run-docker-mosquitto.sh${NC}"
    echo -e "${WHITE}|-- docker-compose.yml${NC}"
    echo -e "${WHITE}+-- README.md${NC}"

    echo ""
    echo -e "${GREEN}=== Next Steps ===${NC}"
    echo -e "${WHITE}1. Review configuration: $BASE_DIR/config/mosquitto.conf${NC}"
    echo -e "${WHITE}2. Change directory: cd \"$BASE_DIR\"${NC}"
    echo -e "${WHITE}3. Deploy container: ./run-docker-mosquitto.sh${NC}"
    echo -e "${WHITE}4. Access UI: http://localhost:8088${NC}"
}

# Main execution
main() {
    echo -e "${GREEN}=== MQTT Mosquitto Setup Script v$SCRIPT_VERSION ===${NC}"

    # Parse command line arguments
    parse_arguments "$@"

    if [[ "$DRY_RUN" == true ]]; then
        log_warn "Running in DRY-RUN mode - no changes will be made"
    fi

    echo -e "${YELLOW}Installation directory: $BASE_DIR${NC}"

    # Validate prerequisites
    validate_prerequisites

    log_info "Starting directory creation process..."

    # Create main directory structure
    create_mqtt_directory_structure "$BASE_DIR"

    # Create configuration files
    log_info "Creating configuration files..."
    create_mosquitto_config_file "$BASE_DIR/config"
    create_password_file_template "$BASE_DIR/config"
    create_acl_file_template "$BASE_DIR/config"

    # Copy transformations folder
    copy_transformations_folder "$BASE_DIR"

    # Copy Docker files
    copy_docker_files "$BASE_DIR"

    # Create README file
    create_readme_file "$BASE_DIR"

    # Display summary
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        log_warn "DRY-RUN complete. No actual changes were made."
        log_info "Run without --dry-run to apply changes"
    else
        display_summary
        echo ""
        log_success "Setup completed successfully!"
    fi
}

# Run main function with all arguments
main "$@"
