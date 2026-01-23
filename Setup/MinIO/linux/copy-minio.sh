#!/bin/bash
# ==============================================================================
# MinIO Docker Setup - File Copy Script (Linux/Ubuntu)
# ==============================================================================
#
# Purpose:
#   Copies MinIO Docker configuration files from the current directory to
#   the system deployment directory. This script prepares the MinIO setup
#   for production deployment on Ubuntu 24.04.
#
# Source Location:
#   The directory where this script is located (auto-detected)
#   Typically: /path/to/Workshop--Data-Integration/Setup/MinIO/linux
#
# Destination Location:
#   /opt/minio (standard location for third-party applications on Linux)
#
# Files Copied:
#   - docker-compose.yml: Docker Compose configuration for MinIO
#   - run-docker-minio.sh: Script to start MinIO container
#
# Requirements:
#   - Ubuntu 24.04 LTS (or compatible Linux distribution)
#   - Bash 4.0 or higher
#   - Root/sudo privileges (required for writing to /opt)
#
# Usage:
#   chmod +x copy-minio.sh    # Make executable (first time only)
#   sudo ./copy-minio.sh      # Run with sudo for /opt access
#
# Exit Codes:
#   0 - Success
#   1 - Error (not running as root, source not found, copy failed, etc.)
# ==============================================================================

# ------------------------------------------------------------------------------
# Color Codes for Output Formatting
# ------------------------------------------------------------------------------
# These ANSI escape codes provide colored terminal output for better readability
# Usage: echo -e "${GREEN}Success message${NC}"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color - resets to default

# ------------------------------------------------------------------------------
# Path Configuration
# ------------------------------------------------------------------------------
# SCRIPT_DIR: Auto-detect the directory where this script is located
#   - ${BASH_SOURCE[0]}: Path to this script
#   - dirname: Extracts directory path
#   - cd && pwd: Resolves to absolute path, following symlinks
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# SOURCE_PATH: Files to copy (from script's directory)
SOURCE_PATH="$SCRIPT_DIR"

# DESTINATION_PATH: Target directory for deployment files
# /opt is the standard Linux directory for optional/third-party software
DESTINATION_PATH="/opt/minio"

# ------------------------------------------------------------------------------
# Display Script Header
# ------------------------------------------------------------------------------
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}MinIO Setup - File Copy Script${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# ------------------------------------------------------------------------------
# Step 1: Validate Root Privileges
# ------------------------------------------------------------------------------
# Check if the script is running as root (UID 0)
# Root access is required to write to /opt directory
# $EUID: Effective User ID (0 = root)

if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}[ERROR] This script requires root privileges to write to /opt/minio${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please run with sudo:${NC}"
    echo -e "  ${GRAY}sudo $0${NC}"
    echo ""
    exit 1
fi

echo -e "${GREEN}[OK] Running with root privileges${NC}"

# ------------------------------------------------------------------------------
# Step 2: Validate Source Directory
# ------------------------------------------------------------------------------
# Verify that the source directory exists and contains the necessary files
# This prevents errors if the script is run from the wrong location

if [ ! -d "$SOURCE_PATH" ]; then
    echo -e "${RED}[ERROR] Source directory does not exist: $SOURCE_PATH${NC}" >&2
    echo ""
    echo -e "${YELLOW}Please verify that:${NC}"
    echo -e "  ${GRAY}1. You are running this script from the correct directory${NC}"
    echo -e "  ${GRAY}2. The MinIO setup files exist in this location${NC}"
    exit 1
fi

# Verify that key files exist in the source directory
COMPOSE_FILE_SRC="$SOURCE_PATH/docker-compose.yml"
RUN_SCRIPT_SRC="$SOURCE_PATH/run-docker-minio.sh"

if [ ! -f "$COMPOSE_FILE_SRC" ]; then
    echo -e "${RED}[ERROR] docker-compose.yml not found in: $SOURCE_PATH${NC}" >&2
    exit 1
fi

if [ ! -f "$RUN_SCRIPT_SRC" ]; then
    echo -e "${RED}[ERROR] run-docker-minio.sh not found in: $SOURCE_PATH${NC}" >&2
    exit 1
fi

echo -e "${GREEN}[OK] Source directory found: $SOURCE_PATH${NC}"
echo -e "${GREEN}[OK] Required files validated${NC}"

# ------------------------------------------------------------------------------
# Step 3: Create Destination Directory
# ------------------------------------------------------------------------------
# Create the destination directory if it doesn't exist
# -p flag: Creates parent directories as needed, no error if already exists

if [ ! -d "$DESTINATION_PATH" ]; then
    echo -e "${YELLOW}[INFO] Creating destination directory: $DESTINATION_PATH${NC}"

    # Create directory with proper permissions
    # 755 = rwxr-xr-x (owner: full, group/others: read+execute)
    mkdir -p "$DESTINATION_PATH"

    # Check if mkdir succeeded
    if [ $? -ne 0 ]; then
        echo -e "${RED}[ERROR] Failed to create destination directory${NC}" >&2
        exit 1
    fi

    echo -e "${GREEN}[OK] Destination directory created successfully${NC}"
else
    echo -e "${GREEN}[OK] Destination directory already exists: $DESTINATION_PATH${NC}"
fi

# ------------------------------------------------------------------------------
# Step 4: Copy Files
# ------------------------------------------------------------------------------
# Copy configuration files and scripts to the deployment directory
# 2>/dev/null suppresses error messages (they're handled by exit code check)

echo ""
echo -e "${CYAN}Copying files...${NC}"
echo -e "  ${GRAY}From: $SOURCE_PATH${NC}"
echo -e "  ${GRAY}To:   $DESTINATION_PATH${NC}"
echo ""

# Copy docker-compose.yml
# This file contains the MinIO container configuration
cp "$SOURCE_PATH/docker-compose.yml" "$DESTINATION_PATH/" 2>/dev/null
COPY_RESULT=$?

# Copy run script
# This script will be used to start/manage the MinIO container
cp "$SOURCE_PATH/run-docker-minio.sh" "$DESTINATION_PATH/" 2>/dev/null
COPY_RESULT=$((COPY_RESULT + $?))

# Copy README if it exists (optional, not critical)
if [ -f "$SOURCE_PATH/README.md" ]; then
    cp "$SOURCE_PATH/README.md" "$DESTINATION_PATH/" 2>/dev/null
fi

# Check if copy operations succeeded
if [ $COPY_RESULT -eq 0 ]; then
    # Make the run script executable
    # 755 permissions = rwxr-xr-x (executable by all, writable by owner)
    chmod +x "$DESTINATION_PATH/run-docker-minio.sh"

    # Verify the script is now executable
    if [ -x "$DESTINATION_PATH/run-docker-minio.sh" ]; then
        echo -e "${GREEN}[SUCCESS] Copy operation completed successfully!${NC}"
        echo ""
        echo -e "${CYAN}Files copied to: $DESTINATION_PATH${NC}"
        echo ""

        # Display next steps
        echo -e "${YELLOW}Next steps:${NC}"
        echo -e "  ${GRAY}1. Review the configuration: sudo nano $DESTINATION_PATH/docker-compose.yml${NC}"
        echo -e "  ${GRAY}2. Ensure Docker is installed and running: docker --version${NC}"
        echo -e "  ${GRAY}3. Start MinIO: sudo $DESTINATION_PATH/run-docker-minio.sh${NC}"
        echo ""

        # Display file list
        echo -e "${CYAN}Deployed files:${NC}"
        ls -lh "$DESTINATION_PATH" | tail -n +2 | awk '{printf "  %s  %s\n", $9, $5}'
        echo ""
    else
        echo -e "${YELLOW}[WARNING] Files copied but run script may not be executable${NC}"
    fi
else
    echo -e "${RED}[ERROR] An error occurred during the copy operation${NC}" >&2
    echo ""
    echo -e "${YELLOW}Troubleshooting:${NC}"
    echo -e "  ${GRAY}- Verify source files exist and are readable${NC}"
    echo -e "  ${GRAY}- Check disk space: df -h /opt${NC}"
    echo -e "  ${GRAY}- Ensure no permission issues${NC}"
    exit 1
fi

# ------------------------------------------------------------------------------
# Script Completed Successfully
# ------------------------------------------------------------------------------
echo -e "${GREEN}Deployment preparation complete!${NC}"
exit 0
