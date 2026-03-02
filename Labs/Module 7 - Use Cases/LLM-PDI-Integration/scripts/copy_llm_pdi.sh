#!/bin/bash

# Script to copy LLM-PDI-Integration from Workshop location to home directory
# and ensure all .sh files are executable

set -e  # Exit on error

SOURCE_DIR="/home/pentaho/Workshop--Data-Integration/Labs/Module 7 - Use Cases/LLM-PDI-Integration"
DEST_DIR="/home/pentaho/LLM-PDI-Integration"

echo "==================================================="
echo "LLM-PDI-Integration Copy Script"
echo "==================================================="
echo ""

# Check if source directory exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo "ERROR: Source directory does not exist:"
    echo "  $SOURCE_DIR"
    exit 1
fi

echo "Source: $SOURCE_DIR"
echo "Destination: $DEST_DIR"
echo ""

# Check if destination already exists
if [ -d "$DEST_DIR" ]; then
    echo "WARNING: Destination directory already exists!"
    echo "  $DEST_DIR"
    read -p "Do you want to remove it and continue? (yes/no): " -r
    echo
    if [[ $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo "Removing existing directory..."
        rm -rf "$DEST_DIR"
        echo "Done."
    else
        echo "Copy cancelled."
        exit 0
    fi
fi

# Copy the directory
echo ""
echo "Copying directory..."
cp -r "$SOURCE_DIR" "$DEST_DIR"
echo "Copy completed."

# Make all .sh files executable
echo ""
echo "Making all .sh files executable..."
SHELL_SCRIPTS=$(find "$DEST_DIR" -type f -name "*.sh")
SCRIPT_COUNT=0

if [ -n "$SHELL_SCRIPTS" ]; then
    while IFS= read -r script; do
        chmod +x "$script"
        echo "  ✓ $script"
        ((SCRIPT_COUNT++))
    done <<< "$SHELL_SCRIPTS"
    echo ""
    echo "Made $SCRIPT_COUNT shell script(s) executable."
else
    echo "  No .sh files found."
fi

# Display summary
echo ""
echo "==================================================="
echo "Copy completed successfully!"
echo "==================================================="
echo ""
echo "Summary:"
echo "  - Source: $SOURCE_DIR"
echo "  - Destination: $DEST_DIR"
echo "  - Shell scripts made executable: $SCRIPT_COUNT"
echo ""
echo "You can now use the LLM-PDI-Integration folder at:"
echo "  $DEST_DIR"
echo ""
