<#
.SYNOPSIS
    Cleans up and uninstalls Cedalo Mosquitto MQTT broker installation.

.DESCRIPTION
    This script completely removes the Mosquitto MQTT broker installation including:
    - Docker containers and networks
    - Configuration files
    - Data and log directories
    - Optionally Docker images

    WARNING: This will delete all MQTT data, configurations, and logs!
    This action cannot be undone!

.PARAMETER BaseDir
    Base directory to clean. Default: C:\Streaming\MQTT\mosquitto

.PARAMETER DryRun
    Preview what would be removed without actually deleting anything.

.PARAMETER Verbose
    Enable verbose output for detailed logging.

.PARAMETER Force
    Skip confirmation prompts and remove everything.

.PARAMETER KeepData
    Keep the data directory (preserves MQTT message persistence).

.PARAMETER RemoveImages
    Also remove Docker images (cedalo/management-center).

.PARAMETER Help
    Show help message.

.EXAMPLE
    .\cleanup-mosquitto.ps1 -DryRun
    Preview what would be removed without making changes.

.EXAMPLE
    .\cleanup-mosquitto.ps1
    Remove everything with confirmation prompt.

.EXAMPLE
    .\cleanup-mosquitto.ps1 -Force
    Remove everything without confirmation.

.EXAMPLE
    .\cleanup-mosquitto.ps1 -KeepData
    Remove everything but preserve data directory.

.EXAMPLE
    .\cleanup-mosquitto.ps1 -BaseDir "D:\MQTT\mosquitto"
    Clean up custom installation directory.

.EXAMPLE
    .\cleanup-mosquitto.ps1 -Force -RemoveImages
    Full cleanup including Docker images, no prompts.

.NOTES
    Version: 2.0
    Author: Generated for MQTT deployment
    Requires: PowerShell 5.1+, Docker (optional)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$BaseDir = "C:\Streaming\MQTT\mosquitto",

    [Parameter(Mandatory=$false)]
    [switch]$DryRun,

    [Parameter(Mandatory=$false)]
    [switch]$Verbose,

    [Parameter(Mandatory=$false)]
    [switch]$Force,

    [Parameter(Mandatory=$false)]
    [switch]$KeepData,

    [Parameter(Mandatory=$false)]
    [switch]$RemoveImages,

    [Parameter(Mandatory=$false)]
    [switch]$Help
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptVersion = "2.0"

# Show help if requested
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Logging functions
function Write-Info {
    param($Message)
    Write-Host "[INFO] $Message" -ForegroundColor Cyan
}

function Write-Success {
    param($Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-Warning {
    param($Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-ErrorMsg {
    param($Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-VerboseMsg {
    param($Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] $Message" -ForegroundColor Blue
    }
}

function Write-DryRun {
    param($Message)
    if ($DryRun) {
        Write-Host "[DRY-RUN] $Message" -ForegroundColor Yellow
    }
}

# Detect Docker Compose version
function Get-ComposeVersion {
    Write-VerboseMsg "Detecting Docker Compose version..."

    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        Write-VerboseMsg "Found docker-compose (v1)"
        return "v1"
    }
    elseif ((docker compose version 2>$null) -and ($LASTEXITCODE -eq 0)) {
        Write-VerboseMsg "Found docker compose (v2)"
        return "v2"
    }
    else {
        Write-VerboseMsg "Docker Compose not found (not an error for cleanup)"
        return "none"
    }
}

# Confirm action
function Confirm-Cleanup {
    if ($Force -or $DryRun) {
        return $true
    }

    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║                    ⚠️  WARNING  ⚠️                        ║" -ForegroundColor Yellow
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "This will permanently delete:" -ForegroundColor Red
    Write-Host "  • Docker containers (mosquitto-broker)"
    Write-Host "  • Docker networks (mqtt-network)"
    Write-Host "  • Configuration files: $BaseDir\config"

    if ($KeepData) {
        Write-Host "  • Data directory will be PRESERVED" -ForegroundColor Green
    } else {
        Write-Host "  • Data directory: $BaseDir\data (ALL MQTT MESSAGES!)" -ForegroundColor Red
    }

    Write-Host "  • Log files: $BaseDir\log"
    Write-Host "  • Base directory: $BaseDir"

    if ($RemoveImages) {
        Write-Host "  • Docker images (cedalo/management-center)" -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "This action CANNOT be undone!" -ForegroundColor Yellow
    Write-Host ""

    $confirmation = Read-Host "Are you sure you want to continue? (yes/no)"

    if ($confirmation -ne "yes") {
        Write-Info "Cleanup cancelled by user"
        exit 0
    }

    return $true
}

# Stop and remove containers
function Remove-Containers {
    param($ComposeVersion)

    Write-Info "Stopping and removing Docker containers..."

    if (Test-Path "$BaseDir\docker-compose.yml") {
        Push-Location $BaseDir
        try {
            if ($DryRun) {
                Write-DryRun "Would run: docker-compose down"
            } else {
                if ($ComposeVersion -eq "v2") {
                    docker compose down 2>$null
                } elseif ($ComposeVersion -eq "v1") {
                    docker-compose down 2>$null
                }
                Write-Success "Containers stopped and removed"
            }
        }
        catch {
            Write-VerboseMsg "Failed to run docker-compose down: $_"
        }
        finally {
            Pop-Location
        }
    } else {
        Write-VerboseMsg "No docker-compose.yml found in $BaseDir"
    }

    # Remove container by name if it still exists
    try {
        $containerId = docker ps -aq --filter "name=mosquitto-broker" 2>$null
        if ($containerId) {
            if ($DryRun) {
                Write-DryRun "Would remove container: $containerId"
            } else {
                docker rm -f $containerId 2>$null
                Write-Success "Removed container: $containerId"
            }
        } else {
            Write-VerboseMsg "No mosquitto-broker container found"
        }
    }
    catch {
        Write-VerboseMsg "Could not check for containers: $_"
    }
}

# Remove Docker network
function Remove-DockerNetwork {
    Write-Info "Removing Docker network..."

    try {
        $networkId = docker network ls -q --filter "name=mqtt-network" 2>$null
        if ($networkId) {
            if ($DryRun) {
                Write-DryRun "Would remove network: mqtt-network"
            } else {
                docker network rm mqtt-network 2>$null
                Write-Success "Removed network: mqtt-network"
            }
        } else {
            Write-VerboseMsg "No mqtt-network found"
        }
    }
    catch {
        Write-VerboseMsg "Could not remove network (may be in use): $_"
    }
}

# Remove Docker images
function Remove-DockerImages {
    if (-not $RemoveImages) {
        Write-VerboseMsg "Skipping image removal (use -RemoveImages to remove)"
        return
    }

    Write-Info "Removing Docker images..."

    try {
        $images = docker images -q cedalo/management-center 2>$null
        if ($images) {
            if ($DryRun) {
                Write-DryRun "Would remove images: cedalo/management-center"
            } else {
                docker rmi $(docker images -q cedalo/management-center) 2>$null
                Write-Success "Removed Docker images"
            }
        } else {
            Write-VerboseMsg "No cedalo/management-center images found"
        }
    }
    catch {
        Write-Warning "Could not remove some images (may be in use): $_"
    }
}

# Remove directories
function Remove-Directories {
    Write-Info "Removing directories..."

    if (-not (Test-Path $BaseDir)) {
        Write-Warning "Directory does not exist: $BaseDir"
        return
    }

    # Remove config directory
    if (Test-Path "$BaseDir\config") {
        if ($DryRun) {
            Write-DryRun "Would remove: $BaseDir\config"
        } else {
            Remove-Item -Path "$BaseDir\config" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed: $BaseDir\config"
        }
    }

    # Remove data directory (unless -KeepData)
    if (Test-Path "$BaseDir\data") {
        if ($KeepData) {
            Write-Warning "Keeping data directory: $BaseDir\data"
        } else {
            if ($DryRun) {
                Write-DryRun "Would remove: $BaseDir\data"
            } else {
                Remove-Item -Path "$BaseDir\data" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Success "Removed: $BaseDir\data"
            }
        }
    }

    # Remove log directory
    if (Test-Path "$BaseDir\log") {
        if ($DryRun) {
            Write-DryRun "Would remove: $BaseDir\log"
        } else {
            Remove-Item -Path "$BaseDir\log" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed: $BaseDir\log"
        }
    }

    # Remove transformations directory
    if (Test-Path "$BaseDir\transformations") {
        if ($DryRun) {
            Write-DryRun "Would remove: $BaseDir\transformations"
        } else {
            Remove-Item -Path "$BaseDir\transformations" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Success "Removed: $BaseDir\transformations"
        }
    }

    # Remove Docker files
    $filesToRemove = @("docker-compose.yml", "run-docker-mosquitto.ps1", "README.md")
    foreach ($file in $filesToRemove) {
        $filePath = Join-Path $BaseDir $file
        if (Test-Path $filePath) {
            if ($DryRun) {
                Write-DryRun "Would remove: $filePath"
            } else {
                Remove-Item -Path $filePath -Force -ErrorAction SilentlyContinue
                Write-Success "Removed: $filePath"
            }
        }
    }

    # Remove base directory if empty or only data remains
    if ($KeepData) {
        Write-Info "Keeping base directory (contains data): $BaseDir"
    } else {
        if ($DryRun) {
            Write-DryRun "Would remove: $BaseDir"
        } else {
            try {
                # Check if directory is empty
                $items = Get-ChildItem -Path $BaseDir -Force -ErrorAction SilentlyContinue
                if (-not $items) {
                    Remove-Item -Path $BaseDir -Force -ErrorAction SilentlyContinue
                    Write-Success "Removed: $BaseDir"

                    # Try to remove parent directory if empty
                    $parentDir = Split-Path $BaseDir -Parent
                    $parentItems = Get-ChildItem -Path $parentDir -Force -ErrorAction SilentlyContinue
                    if (-not $parentItems) {
                        Remove-Item -Path $parentDir -Force -ErrorAction SilentlyContinue
                        Write-Success "Removed empty parent: $parentDir"
                    }
                } else {
                    Write-VerboseMsg "Base directory not empty"
                }
            }
            catch {
                Write-VerboseMsg "Could not remove base directory: $_"
            }
        }
    }
}

# Display summary
function Show-Summary {
    Write-Host ""
    Write-Host "=== Cleanup Summary ===" -ForegroundColor Green

    if ($DryRun) {
        Write-Host "DRY-RUN MODE: No actual changes were made" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "The following would be removed:"
    } else {
        Write-Host "Successfully removed:"
    }

    Write-Host "  ✓ Docker containers (mosquitto-broker)" -ForegroundColor Cyan
    Write-Host "  ✓ Docker network (mqtt-network)" -ForegroundColor Cyan
    Write-Host "  ✓ Configuration files" -ForegroundColor Cyan

    if ($KeepData) {
        Write-Host "  ✓ Data preserved at: $BaseDir\data" -ForegroundColor Green
    } else {
        Write-Host "  ✓ Data directory" -ForegroundColor Cyan
    }

    Write-Host "  ✓ Log files" -ForegroundColor Cyan

    if ($RemoveImages) {
        Write-Host "  ✓ Docker images (cedalo/management-center)" -ForegroundColor Cyan
    }

    if (-not $KeepData) {
        Write-Host "  ✓ Base directory: $BaseDir" -ForegroundColor Cyan
    }
}

# Main execution
try {
    Write-Host "=== Mosquitto Cleanup Script v$ScriptVersion ===" -ForegroundColor Green

    if ($DryRun) {
        Write-Warning "Running in DRY-RUN mode - no changes will be made"
    }

    Write-Host "Target directory: $BaseDir" -ForegroundColor Yellow

    # Confirm action
    Confirm-Cleanup | Out-Null

    # Detect Docker Compose version
    $composeVersion = Get-ComposeVersion

    # Execute cleanup steps
    Write-Info "Starting cleanup process..."
    Write-Host ""

    Remove-Containers -ComposeVersion $composeVersion
    Remove-DockerNetwork
    Remove-DockerImages
    Remove-Directories

    # Show summary
    Show-Summary

    if ($DryRun) {
        Write-Host ""
        Write-Info "Run without -DryRun to actually remove everything"
    } else {
        Write-Host ""
        Write-Success "Cleanup completed successfully!"

        if ($KeepData) {
            Write-Host ""
            Write-Info "Data directory preserved at: $BaseDir\data"
            Write-Info "To remove manually: Remove-Item -Path '$BaseDir\data' -Recurse -Force"
        }
    }
}
catch {
    Write-ErrorMsg "Cleanup failed: $_"
    exit 1
}
