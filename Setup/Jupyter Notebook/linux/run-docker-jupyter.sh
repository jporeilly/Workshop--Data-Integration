#!/bin/bash
# =============================================================================
# JUPYTER NOTEBOOK DOCKER MANAGER (Linux)
# =============================================================================
#
# Purpose:
#   Manages the lifecycle of the Jupyter Lab Docker container used in the
#   PDI-to-Jupyter-Notebook workshop. Provides simple start / stop / restart /
#   status / logs / shell / cleanup actions through a single script.
#
# How it works:
#   The script locates the docker-compose.yml file inside the scripts/
#   subdirectory of the Jupyter working directory, then delegates all
#   container management to Docker Compose. It auto-detects whether the
#   system uses the modern "docker compose" plugin or the legacy standalone
#   "docker-compose" binary.
#
# Prerequisites:
#   - Docker Engine installed and running (https://docs.docker.com/engine/install/)
#   - Docker Compose (plugin or standalone)
#   - The Jupyter environment set up by copy-jupyter.sh (creates ~/Jupyter-Notebook)
#
# Usage:
#   ./run-docker-jupyter.sh [ACTION] [WORKING_DIR]
#
# Arguments:
#   ACTION       One of: start, stop, restart, status, logs, follow, shell,
#                cleanup, help   (default: start)
#   WORKING_DIR  Root of the Jupyter environment (default: ~/Jupyter-Notebook)
#
# Examples:
#   ./run-docker-jupyter.sh start          # Start the container
#   ./run-docker-jupyter.sh stop           # Stop the container
#   ./run-docker-jupyter.sh logs           # View recent logs
#   ./run-docker-jupyter.sh follow         # Tail logs in real time
#   ./run-docker-jupyter.sh shell          # Open a bash shell in the container
#   ./run-docker-jupyter.sh cleanup        # Remove containers & optionally images
#   ./run-docker-jupyter.sh help           # Print full help text
#
# Access:
#   Jupyter Lab URL : http://localhost:8888
#   Token           : datascience
#
# Related scripts:
#   copy-jupyter.sh   Sets up the directory structure and copies files
#   file_watcher.py   Watches pdi-output/ for new CSV files from PDI
# =============================================================================

# Exit immediately if any command fails
set -e

# ---------------------------------------------------------------------------
# ARGUMENTS
# ---------------------------------------------------------------------------
# ACTION      : The operation to perform (defaults to "start").
# WORKING_DIR : The root directory of the Jupyter environment on the host.
# ---------------------------------------------------------------------------
ACTION="${1:-start}"
WORKING_DIR="${2:-$HOME/Jupyter-Notebook}"

# ---------------------------------------------------------------------------
# TERMINAL COLOUR CODES
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ---------------------------------------------------------------------------
# DERIVED PATHS
# ---------------------------------------------------------------------------
# SCRIPTS_DIR  : The scripts/ subdirectory inside the working directory.
# COMPOSE_FILE : Full path to the docker-compose.yml that defines the
#                Jupyter container, volume mounts, ports, and health check.
# ---------------------------------------------------------------------------
SCRIPTS_DIR="$WORKING_DIR/scripts"
COMPOSE_FILE="$SCRIPTS_DIR/docker-compose.yml"

# ---------------------------------------------------------------------------
# FUNCTION: show_help
# ---------------------------------------------------------------------------
# Prints a usage summary with all available actions, access details, and
# volume mappings so the user can quickly find the information they need.
# ---------------------------------------------------------------------------
show_help() {
    echo ""
    echo -e "${MAGENTA}=== Jupyter Notebook Docker Manager (Linux) ===${NC}"
    echo ""
    echo -e "${YELLOW}USAGE:${NC}"
    echo "  ./run-docker-jupyter.sh [ACTION] [WORKING_DIR]"
    echo ""
    echo -e "${YELLOW}ACTIONS:${NC}"
    echo "  start      Start the Jupyter environment (default)"
    echo "  stop       Stop the Jupyter environment"
    echo "  restart    Restart the Jupyter environment"
    echo "  status     Show environment status"
    echo "  logs       Show container logs"
    echo "  follow     Follow container logs (Ctrl+C to stop)"
    echo "  shell      Open shell inside the container"
    echo "  cleanup    Clean up containers and networks"
    echo "  help       Show this help message"
    echo ""
    echo -e "${YELLOW}ACCESS POINT:${NC}"
    echo "  Jupyter Lab: http://localhost:8888"
    echo "  Token: datascience"
    echo ""
    echo -e "${YELLOW}VOLUMES (Host -> Container):${NC}"
    echo "  ~/Jupyter-Notebook/datasets      -> /home/jovyan/datasets"
    echo "  ~/Jupyter-Notebook/notebooks     -> /home/jovyan/notebooks"
    echo "  ~/Jupyter-Notebook/pdi-output    -> /home/jovyan/pdi-output"
    echo "  ~/Jupyter-Notebook/reports       -> /home/jovyan/reports"
    echo "  ~/Jupyter-Notebook/workshop-data -> /home/jovyan/work"
}

# --- Handle 'help' before any filesystem / Docker validation -----------------
if [ "$ACTION" = "help" ]; then
    show_help
    exit 0
fi

# =============================================================================
# VALIDATION CHECKS
# =============================================================================

# --- Ensure the working directory exists (created by copy-jupyter.sh) --------
if [ ! -d "$WORKING_DIR" ]; then
    echo -e "${RED}Error: Directory does not exist: $WORKING_DIR${NC}"
    echo "Run copy-jupyter.sh first to set up the environment."
    exit 1
fi

# --- Ensure the docker-compose.yml file is present ---------------------------
if [ ! -f "$COMPOSE_FILE" ]; then
    echo -e "${RED}Error: docker-compose.yml not found in: $SCRIPTS_DIR${NC}"
    exit 1
fi

# --- Ensure Docker is installed ----------------------------------------------
if ! command -v docker &>/dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker and try again.${NC}"
    exit 1
fi

echo "Docker found: $(docker --version)"

# ---------------------------------------------------------------------------
# AUTO-DETECT DOCKER COMPOSE COMMAND
# ---------------------------------------------------------------------------
# Modern Docker Desktop ships Compose as a plugin ("docker compose").
# Older installations may still have the standalone "docker-compose" binary.
# We try the plugin first, then fall back to the standalone version.
# ---------------------------------------------------------------------------
if docker compose version &>/dev/null 2>&1; then
    COMPOSE_CMD="docker compose"
elif command -v docker-compose &>/dev/null; then
    COMPOSE_CMD="docker-compose"
else
    echo -e "${RED}Error: Docker Compose is not installed or not available.${NC}"
    exit 1
fi

echo "Docker Compose found: $($COMPOSE_CMD version 2>/dev/null)"

# ---------------------------------------------------------------------------
# HELPER FUNCTION: run_compose
# ---------------------------------------------------------------------------
# Runs Docker Compose with the explicit compose file path so that the script
# works regardless of the current working directory.
#
# Arguments:
#   All arguments are forwarded to docker compose (e.g. "up -d", "down").
# ---------------------------------------------------------------------------
run_compose() {
    $COMPOSE_CMD -f "$COMPOSE_FILE" "$@"
}

# =============================================================================
# ACTION DISPATCH
# =============================================================================
# Each case corresponds to a user-facing action. The Docker Compose commands
# are kept simple and delegated through run_compose().
# =============================================================================
case "$ACTION" in

    # -------------------------------------------------------------------------
    # START - Pull images (if needed), create and start the container in
    #         detached mode. Print access information on success.
    # -------------------------------------------------------------------------
    start)
        echo -e "${GREEN}Starting Jupyter Notebook environment...${NC}"
        run_compose up -d

        echo -e "${GREEN}Jupyter environment started successfully!${NC}"
        echo ""
        echo -e "${CYAN}ACCESS INFORMATION:${NC}"
        echo "  Jupyter Lab: http://localhost:8888"
        echo "  Token: datascience"
        echo ""
        echo -e "${CYAN}VOLUME MAPPINGS (Host -> Container):${NC}"
        echo "  ~/Jupyter-Notebook/datasets      -> /home/jovyan/datasets"
        echo "  ~/Jupyter-Notebook/notebooks     -> /home/jovyan/notebooks"
        echo "  ~/Jupyter-Notebook/pdi-output    -> /home/jovyan/pdi-output"
        echo "  ~/Jupyter-Notebook/reports       -> /home/jovyan/reports"
        echo "  ~/Jupyter-Notebook/workshop-data -> /home/jovyan/work"
        echo ""
        echo -e "${CYAN}MANAGEMENT COMMANDS:${NC}"
        echo "  Check status: ./run-docker-jupyter.sh status"
        echo "  View logs:    ./run-docker-jupyter.sh logs"
        echo "  Stop:         ./run-docker-jupyter.sh stop"
        ;;

    # -------------------------------------------------------------------------
    # STOP - Stop and remove the container and its network.
    # -------------------------------------------------------------------------
    stop)
        echo -e "${YELLOW}Stopping Jupyter Notebook environment...${NC}"
        run_compose down
        echo -e "${GREEN}Environment stopped successfully!${NC}"
        ;;

    # -------------------------------------------------------------------------
    # RESTART - Stop then start the container with a brief pause to allow
    #           ports and resources to be fully released.
    # -------------------------------------------------------------------------
    restart)
        echo -e "${YELLOW}Restarting Jupyter Notebook environment...${NC}"
        run_compose down
        sleep 2
        run_compose up -d
        echo -e "${GREEN}Environment restarted successfully!${NC}"
        ;;

    # -------------------------------------------------------------------------
    # STATUS - Show running containers defined in the compose file.
    # -------------------------------------------------------------------------
    status)
        echo -e "${CYAN}Checking Jupyter environment status...${NC}"
        run_compose ps
        ;;

    # -------------------------------------------------------------------------
    # LOGS - Display recent container logs (non-following).
    # -------------------------------------------------------------------------
    logs)
        echo -e "${CYAN}Displaying container logs...${NC}"
        run_compose logs
        ;;

    # -------------------------------------------------------------------------
    # FOLLOW - Tail container logs in real time (Ctrl+C to stop).
    # -------------------------------------------------------------------------
    follow)
        echo -e "${CYAN}Following container logs (Press Ctrl+C to stop)...${NC}"
        run_compose logs -f
        ;;

    # -------------------------------------------------------------------------
    # SHELL - Open an interactive bash session inside the running container.
    #         Useful for installing pip packages, inspecting files, debugging.
    # -------------------------------------------------------------------------
    shell)
        echo -e "${CYAN}Opening shell in Jupyter container...${NC}"
        echo -e "${YELLOW}Type 'exit' to return to your shell${NC}"
        docker exec -it jupyter-datascience /bin/bash
        ;;

    # -------------------------------------------------------------------------
    # CLEANUP - Remove containers and networks. Optionally remove Docker
    #           images and volumes if the user confirms (full cleanup).
    # -------------------------------------------------------------------------
    cleanup)
        echo -e "${YELLOW}Cleaning up Jupyter environment...${NC}"
        read -rp "Remove volumes and images too? (y/N) " response
        if [[ "$response" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Force cleanup - removing volumes and images${NC}"
            run_compose down -v --rmi all
        else
            run_compose down
        fi
        echo -e "${GREEN}Cleanup completed successfully!${NC}"
        ;;

    # -------------------------------------------------------------------------
    # UNKNOWN ACTION - Print an error and show the help text.
    # -------------------------------------------------------------------------
    *)
        echo -e "${RED}Unknown action: $ACTION${NC}"
        show_help
        exit 1
        ;;
esac
