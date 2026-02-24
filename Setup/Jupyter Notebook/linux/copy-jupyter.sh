#!/bin/bash
# =============================================================================
# JUPYTER NOTEBOOK SETUP SCRIPT (Linux)
# =============================================================================
#
# Purpose:
#   This script prepares the Jupyter Notebook environment on a Linux host by
#   creating the required directory structure, copying workshop files (notebooks,
#   datasets, scripts, Docker Compose config) into their correct locations, and
#   setting appropriate file permissions.
#
# What it creates (destination layout):
#   ~/Jupyter-Notebook/
#   ├── datasets/           CSV data files used by notebooks
#   ├── notebooks/          Jupyter notebooks (.ipynb)
#   ├── pdi-output/         Landing zone for PDI transformation output
#   ├── reports/            Generated analysis reports (Excel/CSV)
#   ├── scripts/            Docker Compose, run script, Python helpers
#   └── workshop-data/      General-purpose workspace
#
# Prerequisites:
#   - Bash shell (tested on Ubuntu / Debian / RHEL / macOS)
#   - The workshop repository cloned to ~/Workshop--Data-Integration
#
# Usage:
#   # Default paths (source = this script's directory, dest = ~/Jupyter-Notebook)
#   ./copy-jupyter.sh
#
#   # Custom source and destination
#   ./copy-jupyter.sh "/path/to/source" "/path/to/destination"
#
# Arguments:
#   $1  (optional) Source directory containing workshop files
#   $2  (optional) Destination directory for the Jupyter environment
#
# Notes:
#   - If the destination directory already exists, the script asks for
#     confirmation before overwriting.
#   - The docker-compose.yml copied into scripts/ uses Linux bind-mount
#     paths (~/Jupyter-Notebook/...) so it is ready to run on the host.
#   - File permissions are set so that .sh files are executable (755)
#     and data files are read-only for non-owners (644).
#
# Related scripts:
#   run-docker-jupyter.sh   Starts / stops the Jupyter Docker container
#   file_watcher.py         Watches pdi-output/ for new CSV files from PDI
# =============================================================================

# Exit immediately if any command fails
set -e

# ---------------------------------------------------------------------------
# CONFIGURATION - Default source and destination paths
# ---------------------------------------------------------------------------
# SOURCE_DIR : Where the workshop repository files live (passed as $1 or
#              defaults to the user's home Workshop directory).
# DEST_DIR   : Where the ready-to-use Jupyter environment will be created
#              (passed as $2 or defaults to ~/Jupyter-Notebook).
# SCRIPT_DIR : The directory where THIS script physically resides. Used to
#              locate sibling files (CSV, notebooks, etc.) that live alongside
#              the script in the repository.
# ---------------------------------------------------------------------------
SOURCE_DIR="${1:-$HOME/Workshop--Data-Integration/Setup/Jupyter Notebook}"
DEST_DIR="${2:-$HOME/Jupyter-Notebook}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ---------------------------------------------------------------------------
# TERMINAL COLOUR CODES - Used for colour-coded console output
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
GRAY='\033[0;37m'
NC='\033[0m' # No Color (reset)

# ---------------------------------------------------------------------------
# HELPER FUNCTION: create_dir
# ---------------------------------------------------------------------------
# Creates a directory (including parent directories) if it does not already
# exist. Prints a colour-coded status message either way.
#
# Arguments:
#   $1  Full path of the directory to create
# ---------------------------------------------------------------------------
create_dir() {
    if [ ! -d "$1" ]; then
        mkdir -p "$1"
        echo -e "  ${GREEN}Created: $1${NC}"
    else
        echo -e "  ${YELLOW}Exists: $1${NC}"
    fi
}

# ---------------------------------------------------------------------------
# HELPER FUNCTION: copy_file
# ---------------------------------------------------------------------------
# Copies a single file into a destination directory. If the source file does
# not exist, a warning is printed and the script continues (non-fatal).
#
# Arguments:
#   $1  Full path to the source file
#   $2  Destination directory (file keeps its original name)
# ---------------------------------------------------------------------------
copy_file() {
    local src="$1"
    local dest_dir="$2"
    local filename
    filename=$(basename "$src")

    if [ -f "$src" ]; then
        cp "$src" "$dest_dir/"
        echo -e "  ${GREEN}Copied $filename to $dest_dir/${NC}"
    else
        echo -e "  ${YELLOW}Source file not found: $src${NC}"
    fi
}

# ---------------------------------------------------------------------------
# HELPER FUNCTION: show_tree
# ---------------------------------------------------------------------------
# Displays the directory tree of the given path. Uses the 'tree' command if
# available; otherwise falls back to a manual traversal using 'find' that
# prints a similar indented view (max depth 3 levels).
#
# Arguments:
#   $1  Root path to display
# ---------------------------------------------------------------------------
show_tree() {
    echo -e "\n${BLUE}Directory Tree:${NC}"
    if command -v tree &>/dev/null; then
        # Use the 'tree' utility if installed (cleaner output)
        tree "$1" --charset=ascii
    else
        # Fallback: build a simple tree with find + formatting
        echo "$1"
        find "$1" -maxdepth 3 | sort | while read -r entry; do
            local rel="${entry#$1}"
            [ -z "$rel" ] && continue
            # Calculate depth by counting '/' separators
            local depth
            depth=$(echo "$rel" | tr -cd '/' | wc -c)
            local indent=""
            for ((i=0; i<depth; i++)); do
                indent="$indent    "
            done
            local name
            name=$(basename "$entry")
            if [ -d "$entry" ]; then
                echo -e "${indent}|-- ${CYAN}${name}/${NC}"
            else
                # Show human-readable file sizes
                local size
                size=$(stat --printf="%s" "$entry" 2>/dev/null || stat -f%z "$entry" 2>/dev/null || echo "0")
                if [ "$size" -lt 1024 ]; then
                    echo -e "${indent}|-- ${GRAY}${name} (${size} B)${NC}"
                elif [ "$size" -lt 1048576 ]; then
                    echo -e "${indent}|-- ${GRAY}${name} ($((size / 1024)) KB)${NC}"
                else
                    echo -e "${indent}|-- ${GRAY}${name} ($((size / 1048576)) MB)${NC}"
                fi
            fi
        done
    fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

echo -e "${MAGENTA}=== Jupyter Notebook Setup Script (Linux) ===${NC}"
echo -e "Source Path:      ${SCRIPT_DIR}"
echo -e "Destination Path: ${DEST_DIR}"
echo ""

# --- Validate that the source directory exists --------------------------------
if [ ! -d "$SCRIPT_DIR" ]; then
    echo -e "${RED}Error: Source path does not exist: ${SCRIPT_DIR}${NC}"
    exit 1
fi

# --- Check if the destination already exists (prompt before overwriting) ------
if [ -d "$DEST_DIR" ]; then
    read -rp "Destination directory already exists at $DEST_DIR. Overwrite? (y/N) " response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Operation cancelled.${NC}"
        exit 0
    fi
fi

# =============================================================================
# STEP 1: Create the top-level destination directory
# =============================================================================
echo -e "${BLUE}1. Creating destination directory...${NC}"
create_dir "$DEST_DIR"

# =============================================================================
# STEP 2: Create the Docker volume sub-directories
# =============================================================================
# These directories are bind-mounted into the Jupyter Docker container so that
# files on the host are visible inside the container and vice-versa.
#
#   workshop-data  -> /home/jovyan/work       (general workspace)
#   pdi-output     -> /home/jovyan/pdi-output  (PDI writes CSV here)
#   notebooks      -> /home/jovyan/notebooks   (Jupyter notebooks)
#   datasets       -> /home/jovyan/datasets    (source CSV data)
#   scripts        -> (not mounted; holds Docker config on host only)
#   reports        -> /home/jovyan/reports      (analysis output)
#   transformations -> (not mounted; stores PDI .ktr files on host)
# =============================================================================
echo -e "\n${BLUE}2. Creating Docker volume directories...${NC}"
create_dir "$DEST_DIR/workshop-data"
create_dir "$DEST_DIR/pdi-output"
create_dir "$DEST_DIR/notebooks"
create_dir "$DEST_DIR/datasets"
create_dir "$DEST_DIR/scripts"
create_dir "$DEST_DIR/reports"
create_dir "$DEST_DIR/transformations"

# =============================================================================
# STEP 3: Copy workshop files into their respective directories
# =============================================================================
# Files are sourced from the SCRIPT_DIR (the directory containing this script
# and its sibling files in the repository).
# =============================================================================
echo -e "\n${BLUE}3. Copying files...${NC}"

# --- Datasets: CSV files used as input by the notebooks ----------------------
echo -e "${CYAN}Copying sales data...${NC}"
copy_file "$SCRIPT_DIR/../sales_data.csv" "$DEST_DIR/datasets"

# --- Notebooks: Jupyter .ipynb files ----------------------------------------
echo -e "${CYAN}Copying notebook files...${NC}"
copy_file "$SCRIPT_DIR/../sales_analysis.ipynb" "$DEST_DIR/notebooks"
copy_file "$SCRIPT_DIR/../welcome.ipynb" "$DEST_DIR/notebooks"

# --- Scripts: Docker Compose, run helper, and Python file watcher ------------
echo -e "${CYAN}Copying script files...${NC}"
copy_file "$SCRIPT_DIR/../file_watcher.py" "$DEST_DIR/scripts"

# Copy the Linux docker-compose.yml into the scripts directory
copy_file "$SCRIPT_DIR/docker-compose.yml" "$DEST_DIR/scripts"

# Copy the Docker management script
copy_file "$SCRIPT_DIR/run-docker-jupyter.sh" "$DEST_DIR/scripts"

# Copy the container startup script (auto-installs Python packages)
copy_file "$SCRIPT_DIR/../post-start.sh" "$DEST_DIR/scripts"

# --- Additional datasets ----------------------------------------------------
echo -e "${CYAN}Copying orders data...${NC}"
copy_file "$SCRIPT_DIR/../orders.csv" "$DEST_DIR/datasets"

# =============================================================================
# STEP 4: Create a README inside pdi-output/ explaining its purpose
# =============================================================================
# This file serves as documentation for anyone browsing the directory,
# explaining how PDI and Jupyter share data through this folder.
# =============================================================================
if [ ! -f "$DEST_DIR/pdi-output/README.md" ]; then
    cat > "$DEST_DIR/pdi-output/README.md" << 'READMEEOF'
# PDI Output Directory

This directory is mapped to /home/jovyan/pdi-output in the Docker container.

Use this directory for:
- Output files from Pentaho Data Integration (PDI)
- Processed datasets
- ETL results
- Files shared between PDI (host) and Jupyter (container)

## Usage:
1. Configure PDI transformations to output files here
2. Access files from Jupyter using path /home/jovyan/pdi-output/
3. Process and analyze data using Python/pandas in Jupyter
READMEEOF
    echo -e "  ${GREEN}Created PDI README file${NC}"
fi

# =============================================================================
# STEP 5: Set file permissions
# =============================================================================
# Directories  : 755 (rwxr-xr-x)  - readable and traversable by all
# Data files   : 644 (rw-r--r--)  - readable by all, writable by owner
# Shell scripts: 755 (rwxr-xr-x)  - executable by all
# =============================================================================
echo -e "\n${BLUE}4. Setting permissions...${NC}"
chmod 755 "$DEST_DIR"
chmod 755 "$DEST_DIR"/*/
chmod 644 "$DEST_DIR"/datasets/*.csv 2>/dev/null
chmod 644 "$DEST_DIR"/notebooks/*.ipynb 2>/dev/null
chmod 644 "$DEST_DIR"/scripts/*.py 2>/dev/null
chmod 644 "$DEST_DIR"/scripts/docker-compose.yml 2>/dev/null
chmod 755 "$DEST_DIR"/scripts/*.sh 2>/dev/null
echo -e "  ${GREEN}Permissions set${NC}"

# =============================================================================
# STEP 6: Display the final directory tree
# =============================================================================
echo -e "\n${BLUE}5. Displaying directory structure...${NC}"
show_tree "$DEST_DIR"

# =============================================================================
# DONE - Print next steps for the user
# =============================================================================
echo -e "\n${MAGENTA}Setup Complete! Your Jupyter Notebook environment is ready.${NC}"
echo ""
echo -e "${CYAN}Next steps:${NC}"
echo "  cd $DEST_DIR/scripts"
echo "  ./run-docker-jupyter.sh start"
echo "  Access Jupyter Lab at: http://localhost:8888 (token: datascience)"
