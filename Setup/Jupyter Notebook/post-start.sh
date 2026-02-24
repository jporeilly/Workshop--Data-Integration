#!/bin/bash
# =============================================================================
# JUPYTER CONTAINER STARTUP SCRIPT
# =============================================================================
#
# Purpose:
#   Automatically installs required Python packages before starting Jupyter Lab.
#   This script is bind-mounted into the container and used as the Docker
#   Compose "command", eliminating the need for manual "pip install" after
#   every container recreate.
#
# Packages installed:
#   watchdog    - Filesystem monitoring (used by file_watcher.py on the host)
#   xlsxwriter  - Excel file generation (used by sales_analysis.ipynb)
#
# Usage:
#   This script is NOT run directly. It is referenced in docker-compose.yml:
#     command: bash /usr/local/bin/post-start.sh
#
# Notes:
#   - The --quiet flag suppresses pip output for a clean container log.
#   - "exec" replaces the shell process with Jupyter, ensuring proper signal
#     handling (Ctrl+C, docker stop) reaches the Jupyter process directly.
# =============================================================================

echo "Installing required Python packages..."
pip install --quiet watchdog xlsxwriter 2>/dev/null

echo "Starting Jupyter Lab..."
exec start-notebook.sh \
    --NotebookApp.token=datascience \
    --ip=0.0.0.0 \
    --port=8888 \
    --no-browser
