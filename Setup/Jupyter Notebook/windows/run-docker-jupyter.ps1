# =============================================================================
# JUPYTER NOTEBOOK DOCKER MANAGER (Windows / PowerShell)
# =============================================================================
#
# Purpose:
#   Manages the lifecycle of the Jupyter Lab Docker container used in the
#   PDI-to-Jupyter-Notebook workshop. Provides simple start / stop / restart /
#   status / logs / shell / cleanup / help actions through a single script.
#
# How it works:
#   The script locates the docker-compose.yml file inside the scripts\
#   subdirectory of the Jupyter working directory, then delegates all
#   container management to Docker Compose. It auto-detects whether the
#   system has the legacy standalone "docker-compose" binary or the modern
#   "docker compose" plugin (bundled with Docker Desktop).
#
# Prerequisites:
#   - Windows 10/11 with Docker Desktop installed and running
#   - Docker Compose (included with Docker Desktop)
#   - The Jupyter environment set up by copy-jupyter.ps1 (creates C:\Jupyter-Notebook)
#
# Usage:
#   .\run-docker-jupyter.ps1 [ACTION] [OPTIONS]
#
# Parameters:
#   -Action            One of: start, stop, restart, status, logs, shell,
#                      cleanup, help  (default: start)
#   -WorkingDirectory  Root of the Jupyter environment (default: C:\Jupyter-Notebook)
#   -Follow            When used with "logs", tails the output in real time
#   -Force             When used with "cleanup", also removes images and volumes
#   -OpenBrowser       When used with "start", opens Jupyter Lab in the default browser
#
# Examples:
#   .\run-docker-jupyter.ps1 start                 # Start the container
#   .\run-docker-jupyter.ps1 start -OpenBrowser     # Start and open browser
#   .\run-docker-jupyter.ps1 stop                   # Stop the container
#   .\run-docker-jupyter.ps1 logs -Follow            # Tail logs in real time
#   .\run-docker-jupyter.ps1 shell                   # Open bash inside container
#   .\run-docker-jupyter.ps1 cleanup -Force           # Full cleanup (images + volumes)
#   .\run-docker-jupyter.ps1 help                    # Print help text
#
# Access:
#   Jupyter Lab URL : http://localhost:8888
#   Token           : datascience
#
# Related scripts:
#   copy-jupyter.ps1    Sets up the directory structure and copies files
#   file_watcher.py     Watches pdi-output\ for new CSV files from PDI
# =============================================================================

param(
    # The action to perform (validated against the allowed set)
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "shell", "cleanup", "help")]
    [string]$Action = "start",

    # Root directory of the Jupyter environment (where datasets/, notebooks/, etc. live)
    [string]$WorkingDirectory = "C:\Jupyter-Notebook",

    # Switch: follow log output in real time (for the "logs" action)
    [switch]$Follow,

    # Switch: force full cleanup including images and volumes (for "cleanup")
    [switch]$Force,

    # Switch: open Jupyter Lab in the default browser after "start"
    [switch]$OpenBrowser
)

$workingDirectory = $WorkingDirectory

# =============================================================================
# VALIDATION: Check that the working directory exists
# =============================================================================
# This directory should have been created by copy-jupyter.ps1.
# If it doesn't exist, the user needs to run the setup script first.
# =============================================================================
if (-not (Test-Path $workingDirectory)) {
    Write-Error "Directory does not exist: $workingDirectory"
    exit 1
}

# =============================================================================
# VALIDATION: Check that docker-compose.yml exists in the scripts\ directory
# =============================================================================
$scriptsDir = Join-Path $workingDirectory "scripts"
$composeFile = Join-Path $scriptsDir "docker-compose.yml"
if (-not (Test-Path $composeFile)) {
    Write-Error "docker-compose.yml not found in: $scriptsDir"
    exit 1
}

# =============================================================================
# VALIDATION: Check that Docker is installed and running
# =============================================================================
try {
    $dockerVersion = docker --version 2>$null
    if (-not $dockerVersion) {
        throw "Docker not found"
    }
    Write-Host "Docker found: $dockerVersion"
}
catch {
    Write-Error "Docker is not installed or not running. Please install Docker Desktop and ensure it's running."
    exit 1
}

# =============================================================================
# AUTO-DETECT DOCKER COMPOSE COMMAND
# =============================================================================
# Older Docker Desktop versions ship a standalone "docker-compose" binary.
# Newer versions include Compose as a Docker CLI plugin ("docker compose").
# We try the legacy syntax first, then fall back to the plugin syntax.
# =============================================================================
try {
    $composeVersion = docker-compose --version 2>$null
    if (-not $composeVersion) {
        # Try the modern "docker compose" plugin syntax
        $composeVersion = docker compose version 2>$null
        if (-not $composeVersion) {
            throw "Docker Compose not found"
        }
        $composeCommand = "docker compose"
    } else {
        $composeCommand = "docker-compose"
    }
    Write-Host "Docker Compose found: $composeVersion"
}
catch {
    Write-Error "Docker Compose is not installed or not available."
    exit 1
}

# =============================================================================
# FUNCTION: Show-Help
# =============================================================================
# Displays a usage summary with all available actions, options, volume
# mappings, and access details.
# =============================================================================
function Show-Help {
    Write-Host ""
    Write-Host "=== Jupyter Notebook Docker Manager ===" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "USAGE:" -ForegroundColor Yellow
    Write-Host "  .\run-docker-jupyter.ps1 [ACTION] [OPTIONS]"
    Write-Host ""
    Write-Host "ACTIONS:" -ForegroundColor Yellow
    Write-Host "  start      Start the Jupyter environment (default)"
    Write-Host "  stop       Stop the Jupyter environment"
    Write-Host "  restart    Restart the Jupyter environment"
    Write-Host "  status     Show environment status"
    Write-Host "  logs       Show container logs"
    Write-Host "  shell      Open shell inside the container"
    Write-Host "  cleanup    Clean up containers and networks"
    Write-Host "  help       Show this help message"
    Write-Host ""
    Write-Host "OPTIONS:" -ForegroundColor Yellow
    Write-Host "  -WorkingDirectory  Path to Jupyter directory (default: C:\Jupyter-Notebook)"
    Write-Host "  -Follow           Follow log output (for logs action)"
    Write-Host "  -Force            Force operation (for cleanup action)"
    Write-Host "  -OpenBrowser      Open browser after start"
    Write-Host ""
    Write-Host "ACCESS POINT:" -ForegroundColor Yellow
    Write-Host "  Jupyter Lab: http://localhost:8888"
    Write-Host "  Token: datascience"
    Write-Host ""
    Write-Host "VOLUMES (Host -> Container):" -ForegroundColor Yellow
    Write-Host "  C:\Jupyter-Notebook\datasets      -> /home/jovyan/datasets"
    Write-Host "  C:\Jupyter-Notebook\notebooks     -> /home/jovyan/notebooks"
    Write-Host "  C:\Jupyter-Notebook\pdi-output    -> /home/jovyan/pdi-output"
    Write-Host "  C:\Jupyter-Notebook\reports       -> /home/jovyan/reports"
    Write-Host "  C:\Jupyter-Notebook\workshop-data -> /home/jovyan/work"
}

# --- Handle 'help' before performing any Docker operations -------------------
if ($Action -eq "help") {
    Show-Help
    exit 0
}

# =============================================================================
# ACTION DISPATCH
# =============================================================================
# Each case delegates to Docker Compose. The $composeCommand variable holds
# either "docker-compose" or "docker compose" depending on what was detected.
# We use .Split() to handle the two-word "docker compose" case when invoking
# with the & call operator.
# =============================================================================
try {
    # Change to the scripts directory where docker-compose.yml is located.
    # This ensures relative paths in the compose file resolve correctly.
    $scriptsDir = Join-Path $workingDirectory "scripts"
    Write-Host "Changing to directory: $scriptsDir"
    Set-Location -Path $scriptsDir

    switch ($Action) {
        # =====================================================================
        # START - Pull images (if needed), create and start the container in
        #         detached mode. Print access info and volume mappings.
        # =====================================================================
        "start" {
            Write-Host "Starting Jupyter Notebook environment..." -ForegroundColor Green
            Write-Host "Running $composeCommand up -d..."

            & $composeCommand.Split() up -d

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Jupyter environment started successfully!" -ForegroundColor Green
                Write-Host ""
                Write-Host "ACCESS INFORMATION:" -ForegroundColor Cyan
                Write-Host "  Jupyter Lab: http://localhost:8888"
                Write-Host "  Token: datascience"
                Write-Host ""
                Write-Host "VOLUME MAPPINGS (Host -> Container):" -ForegroundColor Cyan
                Write-Host "  C:\Jupyter-Notebook\datasets      -> /home/jovyan/datasets"
                Write-Host "  C:\Jupyter-Notebook\notebooks     -> /home/jovyan/notebooks"
                Write-Host "  C:\Jupyter-Notebook\pdi-output    -> /home/jovyan/pdi-output"
                Write-Host "  C:\Jupyter-Notebook\reports       -> /home/jovyan/reports"
                Write-Host "  C:\Jupyter-Notebook\workshop-data -> /home/jovyan/work"
                Write-Host ""
                Write-Host "MANAGEMENT COMMANDS:" -ForegroundColor Cyan
                Write-Host "  Check status: $composeCommand ps"
                Write-Host "  View logs: $composeCommand logs"
                Write-Host "  Stop services: $composeCommand down"

                # Optionally open Jupyter Lab in the default browser
                if ($OpenBrowser) {
                    Write-Host "Opening Jupyter Lab in browser..." -ForegroundColor Cyan
                    Start-Process "http://localhost:8888"
                }
            } else {
                Write-Error "Docker Compose failed to start. Exit code: $LASTEXITCODE"
                exit 1
            }
        }

        # =====================================================================
        # STOP - Stop and remove the container and its network.
        # =====================================================================
        "stop" {
            Write-Host "Stopping Jupyter Notebook environment..." -ForegroundColor Yellow
            & $composeCommand.Split() down

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Environment stopped successfully!" -ForegroundColor Green
            } else {
                Write-Error "Failed to stop environment. Exit code: $LASTEXITCODE"
                exit 1
            }
        }

        # =====================================================================
        # RESTART - Stop then start with a brief pause for port release.
        # =====================================================================
        "restart" {
            Write-Host "Restarting Jupyter Notebook environment..." -ForegroundColor Yellow
            & $composeCommand.Split() down
            Start-Sleep -Seconds 2
            & $composeCommand.Split() up -d

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Environment restarted successfully!" -ForegroundColor Green
            } else {
                Write-Error "Failed to restart environment. Exit code: $LASTEXITCODE"
                exit 1
            }
        }

        # =====================================================================
        # STATUS - Show running containers defined in the compose file.
        # =====================================================================
        "status" {
            Write-Host "Checking Jupyter environment status..." -ForegroundColor Cyan
            & $composeCommand.Split() ps
        }

        # =====================================================================
        # LOGS - Display container logs. Use -Follow to tail in real time.
        # =====================================================================
        "logs" {
            Write-Host "Displaying container logs..." -ForegroundColor Cyan
            if ($Follow) {
                Write-Host "Following logs (Press Ctrl+C to stop)..." -ForegroundColor Yellow
                & $composeCommand.Split() logs -f
            } else {
                & $composeCommand.Split() logs
            }
        }

        # =====================================================================
        # SHELL - Open an interactive bash session inside the container.
        #         Useful for installing pip packages, inspecting files, etc.
        # =====================================================================
        "shell" {
            Write-Host "Opening shell in Jupyter container..." -ForegroundColor Cyan
            Write-Host "Type 'exit' to return to PowerShell" -ForegroundColor Yellow
            docker exec -it jupyter-datascience /bin/bash
        }

        # =====================================================================
        # CLEANUP - Remove containers/networks. With -Force, also removes
        #           Docker images and volumes (full reset).
        # =====================================================================
        "cleanup" {
            Write-Host "Cleaning up Jupyter environment..." -ForegroundColor Yellow
            if ($Force) {
                Write-Host "Force cleanup - removing volumes and images" -ForegroundColor Red
                & $composeCommand.Split() down -v --rmi all
            } else {
                & $composeCommand.Split() down
            }

            if ($LASTEXITCODE -eq 0) {
                Write-Host "Cleanup completed successfully!" -ForegroundColor Green
            } else {
                Write-Error "Cleanup failed. Exit code: $LASTEXITCODE"
                exit 1
            }
        }

        # =====================================================================
        # UNKNOWN ACTION (should not reach here due to ValidateSet)
        # =====================================================================
        default {
            Write-Error "Unknown action: $Action"
            Write-Host "Use 'help' action to see available options" -ForegroundColor Yellow
            exit 1
        }
    }
}
catch {
    Write-Error "An error occurred: $_"
    exit 1
}
finally {
    # Return to the original directory the user was in before the script ran
    Pop-Location -ErrorAction SilentlyContinue
}
