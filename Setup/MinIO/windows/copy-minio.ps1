# ==============================================================================
# MinIO Docker Setup - File Copy Script (Windows)
# ==============================================================================
#
# Purpose:
#   Copies MinIO Docker configuration files from the GitHub repository to
#   a deployment directory on the local system.
#
# Source Location:
#   C:\Github\Workshop--Data-Integration\Setup\MinIO\windows
#
# Destination Location:
#   C:\MinIO
#
# Files Copied:
#   - docker-compose.yml: Docker Compose configuration for MinIO
#   - run-docker-minio.ps1: Script to start MinIO container
#
# Requirements:
#   - PowerShell 5.1 or higher
#   - Write access to C:\ drive
#
# Usage:
#   .\copy-minio.ps1
#
# Exit Codes:
#   0 - Success
#   1 - Error (source not found, copy failed, etc.)
# ==============================================================================

# Define source and destination paths
# Source: GitHub repository location with MinIO setup files
$sourcePath = "C:\Github\Workshop--Data-Integration\Setup\MinIO\windows\*"
$destinationPath = "C:\MinIO"

# Extract the base source directory for validation (without the wildcard)
$sourceDirectory = "C:\Github\Workshop--Data-Integration\Setup\MinIO\windows"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MinIO Setup - File Copy Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------------------------------------------------------
# Step 1: Validate Source Directory
# ------------------------------------------------------------------------------
# Check if the source directory exists before attempting to copy
# This prevents errors if the repository path is incorrect or missing

if (-not (Test-Path $sourceDirectory)) {
    Write-Error "Source directory does not exist: $sourceDirectory"
    Write-Host ""
    Write-Host "Please verify that:" -ForegroundColor Yellow
    Write-Host "  1. The GitHub repository is cloned to C:\Github\Workshop--Data-Integration" -ForegroundColor Yellow
    Write-Host "  2. The MinIO setup files exist in Setup\MinIO\windows" -ForegroundColor Yellow
    exit 1
}

Write-Host "[OK] Source directory found: $sourceDirectory" -ForegroundColor Green

# ------------------------------------------------------------------------------
# Step 2: Create Destination Directory
# ------------------------------------------------------------------------------
# Create the destination directory if it doesn't exist
# Using -Force ensures parent directories are created if needed

if (-not (Test-Path $destinationPath)) {
    Write-Host "[INFO] Creating destination directory: $destinationPath" -ForegroundColor Yellow
    try {
        New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        Write-Host "[OK] Destination directory created successfully" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create destination directory: $_"
        exit 1
    }
}
else {
    Write-Host "[OK] Destination directory already exists: $destinationPath" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# Step 3: Copy Files
# ------------------------------------------------------------------------------
# Copy all files and subdirectories from source to destination
# -Recurse: Copies subdirectories and their contents
# -Force: Overwrites existing files without prompting

Write-Host ""
Write-Host "Copying files..." -ForegroundColor Cyan
Write-Host "  From: " -NoNewline; Write-Host "$sourcePath" -ForegroundColor Cyan
Write-Host "  To:   " -NoNewline; Write-Host "$destinationPath" -ForegroundColor Cyan
Write-Host ""

try {
    # Perform the copy operation
    Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force

    # Verify that key files were copied
    $dockerComposeFile = Join-Path $destinationPath "docker-compose.yml"
    $runScriptFile = Join-Path $destinationPath "run-docker-minio.ps1"

    if ((Test-Path $dockerComposeFile) -and (Test-Path $runScriptFile)) {
        Write-Host "[SUCCESS] Copy operation completed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Files copied to: $destinationPath" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Yellow
        Write-Host "  1. Review the docker-compose.yml configuration" -ForegroundColor White
        Write-Host "  2. Ensure Docker Desktop is running" -ForegroundColor White
        Write-Host "  3. Run: .\run-docker-minio.ps1 (from $destinationPath)" -ForegroundColor White
        Write-Host ""
    }
    else {
        Write-Warning "Copy completed but some expected files may be missing"
    }
}
catch {
    Write-Error "An error occurred during the copy operation: $_"
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  - Ensure you have write permissions to C:\MinIO" -ForegroundColor White
    Write-Host "  - Check if any files are locked by other processes" -ForegroundColor White
    Write-Host "  - Try running PowerShell as Administrator" -ForegroundColor White
    exit 1
}
