# ==============================================================================
# MinIO Docker Container - Startup Script (Windows)
# ==============================================================================
#
# Purpose:
#   Validates the environment and starts the MinIO Docker container using
#   Docker Compose. This script ensures all prerequisites are met before
#   attempting to start the service.
#
# Working Directory:
#   C:\MinIO
#
# Requirements:
#   - Docker Desktop installed and running
#   - Docker Compose (included with Docker Desktop)
#   - docker-compose.yml file in C:\MinIO
#
# What it does:
#   1. Validates that the working directory exists
#   2. Checks for docker-compose.yml configuration file
#   3. Verifies Docker is installed and running
#   4. Determines which Docker Compose command to use (old or new syntax)
#   5. Starts MinIO container in detached mode
#   6. Provides access information and management commands
#
# Usage:
#   .\run-docker-minio.ps1
#
# Exit Codes:
#   0 - Success (MinIO started successfully)
#   1 - Error (directory not found, Docker not running, etc.)
# ==============================================================================

# Define the working directory where MinIO files are located
$workingDirectory = "C:\MinIO"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MinIO Docker Container - Startup" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# Step 1: Validate Working Directory
# ------------------------------------------------------------------------------
# Ensure the deployment directory exists before proceeding
# This directory should contain the docker-compose.yml file

if (-not (Test-Path $workingDirectory)) {
    Write-Error "Directory does not exist: $workingDirectory"
    Write-Host ""
    Write-Host "Please run the copy-minio.ps1 script first to set up the directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Working directory found: $workingDirectory" -ForegroundColor Green

# ------------------------------------------------------------------------------
# Step 2: Validate Docker Compose Configuration File
# ------------------------------------------------------------------------------
# Check if docker-compose.yml exists in the working directory
# This file contains the MinIO container configuration

$composeFile = Join-Path $workingDirectory "docker-compose.yml"
if (-not (Test-Path $composeFile)) {
    Write-Error "docker-compose.yml not found in: $workingDirectory"
    Write-Host ""
    Write-Host "Please ensure the docker-compose.yml file exists in the directory." -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Configuration file found: docker-compose.yml" -ForegroundColor Green

# ------------------------------------------------------------------------------
# Step 3: Check Docker Installation
# ------------------------------------------------------------------------------
# Verify that Docker is installed and accessible from the command line
# Docker Desktop must be running for this to succeed

try {
    # Attempt to get Docker version
    # 2>$null suppresses error output if Docker is not found
    $dockerVersion = docker --version 2>$null

    if (-not $dockerVersion) {
        throw "Docker not found"
    }

    Write-Host "[OK] Docker found: $dockerVersion" -ForegroundColor Green
}
catch {
    Write-Error "Docker is not installed or not running."
    Write-Host ""
    Write-Host "Please install Docker Desktop and ensure it's running:" -ForegroundColor Yellow
    Write-Host "  Download from: https://www.docker.com/products/docker-desktop" -ForegroundColor White
    Write-Host ""
    Write-Host "After installation:" -ForegroundColor Yellow
    Write-Host "  1. Start Docker Desktop" -ForegroundColor White
    Write-Host "  2. Wait for Docker to finish starting (check system tray icon)" -ForegroundColor White
    Write-Host "  3. Run this script again" -ForegroundColor White
    exit 1
}

# ------------------------------------------------------------------------------
# Step 4: Determine Docker Compose Command
# ------------------------------------------------------------------------------
# Docker Desktop now includes Docker Compose V2 with 'docker compose' syntax
# Older versions used standalone 'docker-compose' command
# Try both to ensure compatibility

$composeCommand = $null

try {
    # Try standalone docker-compose first (older versions)
    $composeVersion = docker-compose --version 2>$null
    if ($composeVersion) {
        $composeCommand = "docker-compose"
        Write-Host "[OK] Docker Compose found: $composeVersion" -ForegroundColor Green
    }
    else {
        # Try docker compose (V2, integrated with Docker CLI)
        $composeVersion = docker compose version 2>$null
        if ($composeVersion) {
            $composeCommand = "docker compose"
            Write-Host "[OK] Docker Compose found: $composeVersion" -ForegroundColor Green
        }
        else {
            throw "Docker Compose not found"
        }
    }
}
catch {
    Write-Error "Docker Compose is not installed or not available."
    Write-Host ""
    Write-Host "Docker Compose should be included with Docker Desktop." -ForegroundColor Yellow
    Write-Host "Please ensure Docker Desktop is up to date." -ForegroundColor Yellow
    exit 1
}

# ------------------------------------------------------------------------------
# Step 5: Start MinIO Container
# ------------------------------------------------------------------------------
# Change to the working directory and start the container using Docker Compose
# -d flag runs container in detached mode (background)

Write-Host ""
Write-Host "Starting MinIO container..." -ForegroundColor Cyan
Write-Host ""

try {
    # Save the current directory to restore later
    Push-Location

    # Change to the MinIO directory where docker-compose.yml is located
    Set-Location -Path $workingDirectory
    Write-Host "[INFO] Changed to directory: $workingDirectory" -ForegroundColor Gray

    # Execute docker-compose up command
    # Split the command for proper execution with & operator
    Write-Host "[INFO] Running: $composeCommand up -d" -ForegroundColor Gray
    Write-Host ""

    # Run docker-compose up in detached mode
    # This will pull the image if needed and start the container
    if ($composeCommand -eq "docker-compose") {
        docker-compose up -d
    }
    else {
        docker compose up -d
    }

    # Check if the command succeeded
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "[SUCCESS] MinIO started successfully!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""

        # Display access information
        Write-Host "Access Information:" -ForegroundColor Cyan
        Write-Host "  MinIO Console: http://localhost:9002" -ForegroundColor White
        Write-Host "  MinIO API:     http://localhost:9000" -ForegroundColor White
        Write-Host ""
        Write-Host "Default Credentials:" -ForegroundColor Cyan
        Write-Host "  Username: minioadmin" -ForegroundColor White
        Write-Host "  Password: minioadmin" -ForegroundColor White
        Write-Host ""
        Write-Host "  WARNING: Change these credentials for production use!" -ForegroundColor Yellow
        Write-Host ""

        # Display management commands
        Write-Host "Management Commands:" -ForegroundColor Cyan
        Write-Host "  Check status:  $composeCommand ps" -ForegroundColor White
        Write-Host "  View logs:     $composeCommand logs" -ForegroundColor White
        Write-Host "  Follow logs:   $composeCommand logs -f" -ForegroundColor White
        Write-Host "  Stop service:  $composeCommand down" -ForegroundColor White
        Write-Host "  Restart:       $composeCommand restart" -ForegroundColor White
        Write-Host ""
        Write-Host "Run these commands from: $workingDirectory" -ForegroundColor Gray
        Write-Host ""
    }
    else {
        Write-Error "Docker Compose failed to start. Exit code: $LASTEXITCODE"
        Write-Host ""
        Write-Host "Troubleshooting:" -ForegroundColor Yellow
        Write-Host "  1. Check if ports 9000 or 9002 are already in use" -ForegroundColor White
        Write-Host "  2. Ensure Docker Desktop has sufficient resources allocated" -ForegroundColor White
        Write-Host "  3. Check Docker Desktop logs for errors" -ForegroundColor White
        Write-Host "  4. Try running: $composeCommand logs" -ForegroundColor White
        exit 1
    }
}
catch {
    Write-Error "An error occurred while running Docker Compose: $_"
    Write-Host ""
    Write-Host "Please check the error message above and try again." -ForegroundColor Yellow
    exit 1
}
finally {
    # Return to original directory regardless of success or failure
    Pop-Location -ErrorAction SilentlyContinue
}
