#!/bin/bash
# ==============================================================================
# MinIO Docker Container - Startup Script (Linux/Ubuntu)
# ==============================================================================
#
# Purpose:
#   Validates the environment and starts the MinIO Docker container using
#   Docker Compose. This script performs comprehensive checks to ensure all
#   prerequisites are met before attempting to start the service.
#
# Working Directory:
#   /opt/minio
#
# Requirements:
#   - Ubuntu 24.04 LTS (or compatible Linux distribution)
#   - Docker Engine installed and running
#   - Docker Compose V2 plugin or standalone binary
#   - docker-compose.yml file in /opt/minio
#   - Root/sudo privileges (for Docker access)
#
# What it does:
#   1. Validates that the working directory exists
#   2. Checks for docker-compose.yml configuration file
#   3. Verifies Docker is installed and daemon is running
#   4. Determines which Docker Compose command to use (V1 vs V2)
#   5. Starts MinIO container in detached mode (background)
#   6. Provides access information, credentials, and management commands
#
# Usage:
#   sudo /opt/minio/run-docker-minio.sh
#
# Exit Codes:
#   0 - Success (MinIO started successfully)
#   1 - Error (directory not found, Docker not running, startup failed, etc.)
# ==============================================================================

# ------------------------------------------------------------------------------
# Color Codes for Output Formatting
# ------------------------------------------------------------------------------
# ANSI escape codes for colored terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color - resets to default

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
# Define the working directory where MinIO files are deployed
WORKING_DIRECTORY="/opt/minio"

# ------------------------------------------------------------------------------
# Display Script Header
# ------------------------------------------------------------------------------
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}MinIO Docker Container - Startup${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# Step 1: Validate Working Directory
# ------------------------------------------------------------------------------
# Ensure the deployment directory exists before proceeding
# This directory should contain the docker-compose.yml file
# -d checks if path exists and is a directory

if [ ! -d "$WORKING_DIRECTORY" ]; then
    echo -e "${RED}[ERROR] Directory does not exist: $WORKING_DIRECTORY${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please run the copy-minio.sh script first to set up the directory:${NC}"
    echo -e "  ${GRAY}sudo ./copy-minio.sh${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK] Working directory found: $WORKING_DIRECTORY${NC}"

# ------------------------------------------------------------------------------
# Step 2: Validate Docker Compose Configuration File
# ------------------------------------------------------------------------------
# Check if docker-compose.yml exists in the working directory
# This file contains the MinIO container configuration (image, ports, volumes)
# -f checks if path exists and is a regular file

COMPOSE_FILE="$WORKING_DIRECTORY/docker-compose.yml"
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}[ERROR] docker-compose.yml not found in: $WORKING_DIRECTORY${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please ensure the docker-compose.yml file exists in the directory.${NC}"
    echo -e "${YELLOW}You may need to run the copy-minio.sh script again.${NC}"
    exit 1
fi

echo -e "${GREEN}[OK] Configuration file found: docker-compose.yml${NC}"

# ------------------------------------------------------------------------------
# Step 3: Validate Docker Installation
# ------------------------------------------------------------------------------
# Verify that Docker is installed and accessible from the command line
# command -v checks if a command exists in PATH
# &> redirects both stdout and stderr to /dev/null (silent check)

if ! command -v docker &> /dev/null; then
    echo -e "${RED}[ERROR] Docker is not installed${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please install Docker Engine:${NC}"
    echo -e "  ${GRAY}sudo apt update${NC}"
    echo -e "  ${GRAY}sudo apt install docker.io docker-compose-plugin${NC}"
    echo ""
    echo -e "${YELLOW}Or follow the official installation guide:${NC}"
    echo -e "  ${GRAY}https://docs.docker.com/engine/install/ubuntu/${NC}"
    exit 1
fi

# Get Docker version for informational output
# 2>&1 redirects stderr to stdout for capturing error messages
DOCKER_VERSION=$(docker --version 2>&1)

# Check if Docker daemon is running by attempting to query Docker info
# If this fails, Docker is installed but not running
if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Docker is installed but not running${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please start Docker service:${NC}"
    echo -e "  ${GRAY}sudo systemctl start docker${NC}"
    echo -e "  ${GRAY}sudo systemctl enable docker  # Enable auto-start at boot${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK] Docker found: $DOCKER_VERSION${NC}"

# ------------------------------------------------------------------------------
# Step 4: Determine Docker Compose Command
# ------------------------------------------------------------------------------
# Modern Docker installations include Docker Compose V2 as a plugin: 'docker compose'
# Older installations use standalone binary: 'docker-compose'
# Try both to ensure compatibility with different Docker setups

COMPOSE_COMMAND=""

# Try standalone docker-compose first (V1)
# &> /dev/null redirects all output, making this a silent check
if command -v docker-compose &> /dev/null; then
    COMPOSE_COMMAND="docker-compose"
    COMPOSE_VERSION=$(docker-compose --version 2>&1)
    echo -e "${GREEN}[OK] Docker Compose found: $COMPOSE_VERSION${NC}"
# If standalone not found, try Docker Compose V2 plugin
elif docker compose version &> /dev/null; then
    COMPOSE_COMMAND="docker compose"
    COMPOSE_VERSION=$(docker compose version 2>&1)
    echo -e "${GREEN}[OK] Docker Compose found: $COMPOSE_VERSION${NC}"
else
    # Neither version found - installation required
    echo -e "${RED}[ERROR] Docker Compose is not installed or not available${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please install Docker Compose:${NC}"
    echo -e "  ${GRAY}# For Docker Compose V2 (plugin):${NC}"
    echo -e "  ${GRAY}sudo apt update${NC}"
    echo -e "  ${GRAY}sudo apt install docker-compose-plugin${NC}"
    echo ""
    echo -e "  ${GRAY}# Or for standalone docker-compose V1:${NC}"
    echo -e "  ${GRAY}sudo apt install docker-compose${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Step 5: Start MinIO Container
# ------------------------------------------------------------------------------
# Change to the working directory and start the container using Docker Compose
# The -d flag runs the container in detached mode (background)

echo ""
echo -e "${CYAN}Starting MinIO container...${NC}"
echo ""

# Save the current directory so we can return to it later
ORIGINAL_DIR=$(pwd)

# Change to the MinIO directory where docker-compose.yml is located
# Docker Compose looks for docker-compose.yml in the current directory
cd "$WORKING_DIRECTORY" || exit 1

echo -e "${GRAY}[INFO] Changed to directory: $WORKING_DIRECTORY${NC}"
echo -e "${GRAY}[INFO] Running: $COMPOSE_COMMAND up -d${NC}"
echo ""

# Execute docker-compose up command
# -d flag: Detached mode - runs containers in the background
# This will:
#   1. Pull the MinIO image if not already present
#   2. Create the container if it doesn't exist
#   3. Start the container
#   4. Create the Docker volume if needed
$COMPOSE_COMMAND up -d

# Capture the exit code of the docker-compose command
EXIT_CODE=$?

# ------------------------------------------------------------------------------
# Step 6: Report Results
# ------------------------------------------------------------------------------
# Check if the command succeeded (exit code 0)

if [ $EXIT_CODE -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}[SUCCESS] MinIO started successfully!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""

    # Display access information
    echo -e "${CYAN}Access Information:${NC}"
    echo -e "  ${GREEN}MinIO Console:${NC} http://localhost:9002"
    echo -e "  ${GREEN}MinIO API:${NC}     http://localhost:9000"
    echo ""

    # Display default credentials with security warning
    echo -e "${CYAN}Default Credentials:${NC}"
    echo -e "  ${GREEN}Username:${NC} minioadmin"
    echo -e "  ${GREEN}Password:${NC} minioadmin"
    echo ""
    echo -e "  ${YELLOW}⚠ WARNING: Change these credentials for production use!${NC}"
    echo ""

    # Display management commands for operating the container
    echo -e "${CYAN}Management Commands:${NC}"
    echo -e "  ${GREEN}Check status:${NC}  $COMPOSE_COMMAND ps"
    echo -e "  ${GREEN}View logs:${NC}     $COMPOSE_COMMAND logs"
    echo -e "  ${GREEN}Follow logs:${NC}   $COMPOSE_COMMAND logs -f"
    echo -e "  ${GREEN}Stop service:${NC}  $COMPOSE_COMMAND down"
    echo -e "  ${GREEN}Restart:${NC}       $COMPOSE_COMMAND restart"
    echo ""
    echo -e "${GRAY}Run these commands from: $WORKING_DIRECTORY${NC}"
    echo ""

    # Additional helpful information
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Open http://localhost:9002 in your browser"
    echo -e "  2. Login with the default credentials"
    echo -e "  3. Create a new bucket for storing data"
    echo -e "  4. ${YELLOW}Change the default credentials!${NC}"
    echo ""
else
    # Startup failed - provide troubleshooting guidance
    echo ""
    echo -e "${RED}[ERROR] Docker Compose failed to start. Exit code: $EXIT_CODE${NC}" >&2
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  ${GRAY}1. Check if ports 9000 or 9002 are already in use:${NC}"
    echo -e "     ${GRAY}sudo netstat -tlnp | grep -E ':(9000|9002)'${NC}"
    echo ""
    echo -e "  ${GRAY}2. View detailed logs:${NC}"
    echo -e "     ${GRAY}$COMPOSE_COMMAND logs${NC}"
    echo ""
    echo -e "  ${GRAY}3. Ensure Docker has sufficient resources${NC}"
    echo -e "  ${GRAY}4. Check Docker service status:${NC}"
    echo -e "     ${GRAY}sudo systemctl status docker${NC}"
    echo ""
    echo -e "  ${GRAY}5. Try stopping any existing MinIO container:${NC}"
    echo -e "     ${GRAY}$COMPOSE_COMMAND down${NC}"
    echo ""

    # Return to original directory before exiting
    cd "$ORIGINAL_DIR"
    exit 1
fi

# ------------------------------------------------------------------------------
# Cleanup and Exit
# ------------------------------------------------------------------------------
# Return to the original directory
cd "$ORIGINAL_DIR"

# Exit successfully
exit 0
