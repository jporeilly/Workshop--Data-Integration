<#
.SYNOPSIS
    Manages Cedalo Mosquitto MQTT broker Docker container.

.DESCRIPTION
    This script manages the Cedalo Mosquitto MQTT broker Docker container.
    It handles deployment, starting, stopping, and monitoring of the service.
    Supports multiple actions: start, stop, restart, status, and logs.

.PARAMETER BaseDir
    Base directory for MQTT installation. Default: C:\Streaming\MQTT\mosquitto

.PARAMETER Action
    Action to perform: start, stop, restart, status, logs. Default: start

.PARAMETER Verbose
    Enable verbose output for detailed logging.

.PARAMETER DryRun
    Preview actions without making changes.

.PARAMETER SkipPull
    Skip pulling latest Docker image.

.PARAMETER NoLogs
    Don't show logs after starting container.

.PARAMETER Help
    Show help message.

.EXAMPLE
    .\run-docker-mosquitto.ps1
    Start container with default settings.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -Action stop
    Stop the running container.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -Action restart
    Restart the container.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -Action status
    Check container status.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -Action logs
    View container logs.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -BaseDir "D:\MQTT\mosquitto"
    Start with custom directory.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -DryRun
    Preview actions without making changes.

.EXAMPLE
    .\run-docker-mosquitto.ps1 -SkipPull -NoLogs
    Start without pulling image and without showing logs.

.NOTES
    Version: 2.0
    Author: Generated for MQTT deployment
    Requires: Docker and Docker Compose installed
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Base directory for MQTT installation")]
    [string]$BaseDir = "C:\Streaming\MQTT\mosquitto",

    [Parameter(Mandatory=$false, HelpMessage="Action to perform")]
    [ValidateSet("start", "stop", "restart", "status", "logs")]
    [string]$Action = "start",

    [Parameter(Mandatory=$false, HelpMessage="Enable verbose output")]
    [switch]$Verbose,

    [Parameter(Mandatory=$false, HelpMessage="Preview actions without making changes")]
    [switch]$DryRun,

    [Parameter(Mandatory=$false, HelpMessage="Skip pulling latest Docker image")]
    [switch]$SkipPull,

    [Parameter(Mandatory=$false, HelpMessage="Don't show logs after starting")]
    [switch]$NoLogs,

    [Parameter(Mandatory=$false, HelpMessage="Show help message")]
    [switch]$Help
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptVersion = "2.0"
$DockerComposeFile = "docker-compose.yml"

# Show help if requested
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-VerboseMsg {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] " -ForegroundColor Blue -NoNewline
        Write-Host $Message
    }
}

function Write-DryRun {
    param([string]$Message)
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -ForegroundColor Yellow -NoNewline
        Write-Host $Message
    }
}

# Display script header
Write-Host ""
Write-Host "=== Mosquitto Docker Deployment v$ScriptVersion ===" -ForegroundColor Green

if ($DryRun) {
    Write-Warning "Running in DRY-RUN mode - no changes will be made"
}

Write-Host "Working directory: " -NoNewline
Write-Host $BaseDir -ForegroundColor Yellow
Write-Host "Action: " -NoNewline
Write-Host $Action -ForegroundColor Yellow
Write-Host ""

# Validate prerequisites
function Test-Prerequisites {
    Write-VerboseMsg "Validating prerequisites..."

    # Validate base directory path
    if ([string]::IsNullOrWhiteSpace($BaseDir)) {
        Write-ErrorMsg "Base directory cannot be empty"
        exit 1
    }

    Write-VerboseMsg "Prerequisites validated successfully"
}

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check Docker installation and status
function Test-DockerEnvironment {
    Write-Info "Checking Docker environment..."

    try {
        # Check if Docker is installed
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker not found in PATH"
        }
        Write-Success "Docker found: $dockerVersion"

        # Check if Docker is running
        docker ps >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMsg "Docker is installed but not running"
            Write-Info "Please start Docker Desktop and try again"
            exit 1
        }
        Write-Success "Docker is running"

        # Check if docker-compose is available
        docker-compose --version >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Try docker compose (newer syntax)
            docker compose version >$null 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Docker Compose not available"
            }
            Write-Success "Docker Compose (v2) is available"
            return "v2"
        } else {
            Write-Success "Docker Compose (v1) is available"
            return "v1"
        }
    }
    catch {
        Write-ErrorMsg "Docker environment check failed: $_"
        Write-Info "Please ensure Docker Desktop is installed and running"
        exit 1
    }
}

# Function to verify directory structure exists
function Test-DirectoryStructure {
    Write-Info "Verifying directory structure..."

    $requiredDirs = @(
        $BaseDir,
        "$BaseDir\config",
        "$BaseDir\data",
        "$BaseDir\log"
    )

    $missingDirs = @()
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            $missingDirs += $dir
        }
    }

    if ($missingDirs.Count -gt 0) {
        Write-ErrorMsg "Missing required directories:"
        foreach ($dir in $missingDirs) {
            Write-Host "  - " -NoNewline -ForegroundColor Red
            Write-Host $dir -ForegroundColor Red
        }
        Write-Info "Run the setup script first: .\copy-mosquitto.ps1"
        exit 1
    }

    Write-Success "Directory structure verified"
}

# Function to check if docker-compose.yml exists
function Test-DockerComposeFile {
    $composeFile = Join-Path $BaseDir $DockerComposeFile

    if (-not (Test-Path $composeFile)) {
        Write-ErrorMsg "docker-compose.yml not found at: $composeFile"
        Write-Info "Please ensure docker-compose.yml is in the mosquitto directory"
        return $false
    }

    Write-Success "docker-compose.yml found"
    Write-VerboseMsg "Compose file: $composeFile"
    return $true
}

# Execute docker-compose command
function Invoke-ComposeCommand {
    param(
        [string]$ComposeVersion,
        [string]$Command
    )

    Write-VerboseMsg "Running: docker-compose $Command"

    if ($DryRun) {
        Write-DryRun "Would execute: docker-compose $Command"
        return
    }

    Push-Location $BaseDir
    try {
        if ($ComposeVersion -eq "v2") {
            Invoke-Expression "docker compose $Command"
        } else {
            Invoke-Expression "docker-compose $Command"
        }
    }
    finally {
        Pop-Location
    }
}

# Function to stop existing containers
function Stop-Containers {
    param([string]$ComposeVersion)

    Write-Info "Stopping containers..."

    Push-Location $BaseDir
    try {
        $containers = ""
        if ($ComposeVersion -eq "v2") {
            $containers = docker compose ps -q 2>$null
        } else {
            $containers = docker-compose ps -q 2>$null
        }

        if ($containers) {
            Invoke-ComposeCommand -ComposeVersion $ComposeVersion -Command "down"
            Write-Success "Containers stopped"
        } else {
            Write-Info "No running containers to stop"
        }
    }
    finally {
        Pop-Location
    }
}

# Function to start the Mosquitto container
function Start-MosquittoContainer {
    param([string]$ComposeVersion)

    Write-Info "Starting Cedalo Mosquitto container..."

    # Pull the latest image if not skipped
    if (-not $SkipPull) {
        Write-Info "Pulling latest Cedalo Mosquitto image..."
        Invoke-ComposeCommand -ComposeVersion $ComposeVersion -Command "pull"

        if ($LASTEXITCODE -ne 0 -and -not $DryRun) {
            Write-ErrorMsg "Failed to pull Docker image"
            exit 1
        }
        Write-Success "Image pulled successfully"
    } else {
        Write-Info "Skipping image pull (-SkipPull flag)"
    }

    # Start the container
    Write-Info "Starting Mosquitto container..."
    Invoke-ComposeCommand -ComposeVersion $ComposeVersion -Command "up -d"

    if ($LASTEXITCODE -ne 0 -and -not $DryRun) {
        Write-ErrorMsg "Failed to start container"
        Write-Info "Check logs with: docker-compose logs"
        exit 1
    }
    Write-Success "Container started successfully"

    if (-not $DryRun) {
        # Wait for container to be ready
        Write-Info "Waiting for container to be ready..."
        Start-Sleep -Seconds 5

        # Check if container is running
        $containerId = docker ps -q --filter "name=mosquitto-broker" 2>$null
        if ($containerId) {
            Write-Success "Mosquitto broker is running (Container ID: $containerId)"
        } else {
            Write-Warning "Container may not be running properly"
        }
    }
}

# Function to show container status
function Show-Status {
    param([string]$ComposeVersion)

    Write-Host ""
    Write-Host "Container Status:" -ForegroundColor Cyan
    Push-Location $BaseDir
    try {
        if ($ComposeVersion -eq "v2") {
            docker compose ps
        } else {
            docker-compose ps
        }
    }
    finally {
        Pop-Location
    }

    # Check if container is running
    $containerId = docker ps -q --filter "name=mosquitto-broker" 2>$null
    if ($containerId) {
        Write-Host ""
        Write-Success "Mosquitto broker is running"

        # Show basic stats
        Write-Host ""
        Write-Host "Container Stats:" -ForegroundColor Cyan
        docker stats --no-stream $containerId
    } else {
        Write-Host ""
        Write-Warning "Mosquitto broker is not running"
    }
}

# Function to show logs
function Show-Logs {
    param([string]$ComposeVersion)

    Write-Info "Showing container logs (Ctrl+C to exit)..."
    Push-Location $BaseDir
    try {
        if ($ComposeVersion -eq "v2") {
            docker compose logs -f --tail=100
        } else {
            docker-compose logs -f --tail=100
        }
    }
    finally {
        Pop-Location
    }
}

# Function to test MQTT connectivity
function Test-MQTTConnectivity {
    Write-Info "Testing MQTT connectivity..."

    $ports = @(
        @{ Port = 1883; Name = "MQTT" },
        @{ Port = 9001; Name = "WebSocket" },
        @{ Port = 8088; Name = "Management Center" }
    )

    foreach ($portInfo in $ports) {
        try {
            $connection = Test-NetConnection -ComputerName localhost -Port $portInfo.Port -InformationLevel Quiet -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            if ($connection) {
                Write-Success "$($portInfo.Name) port $($portInfo.Port) is accessible"
            } else {
                Write-Warning "$($portInfo.Name) port $($portInfo.Port) is not accessible"
            }
        }
        catch {
            Write-Warning "$($portInfo.Name) port $($portInfo.Port) is not accessible"
        }
    }
}

# Function to display connection information
function Show-ConnectionInfo {
    Write-Host ""
    Write-Host "=== Connection Information ===" -ForegroundColor Cyan
    Write-Host "MQTT Broker:" -ForegroundColor White
    Write-Host "  Host: localhost"
    Write-Host "  Port: 1883"
    Write-Host "  Protocol: MQTT"
    Write-Host ""
    Write-Host "WebSocket Connection:" -ForegroundColor White
    Write-Host "  Host: localhost"
    Write-Host "  Port: 9001"
    Write-Host "  Protocol: WebSocket"
    Write-Host ""
    Write-Host "Management Center UI:" -ForegroundColor White
    Write-Host "  URL: " -NoNewline
    Write-Host "http://localhost:8088" -ForegroundColor Cyan
    Write-Host "  Username: cedalo"
    Write-Host "  Password: password"
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor White
    Write-Host "  Config: $BaseDir\config\mosquitto.conf"
    Write-Host "  Data: $BaseDir\data"
    Write-Host "  Logs: $BaseDir\log"
}

# Function to display management commands
function Show-ManagementCommands {
    Write-Host ""
    Write-Host "=== Management Commands ===" -ForegroundColor Cyan
    Write-Host "View logs:" -ForegroundColor White
    Write-Host "  .\run-docker-mosquitto.ps1 -Action logs" -ForegroundColor DarkGray
    Write-Host "  docker-compose logs -f" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Container management:" -ForegroundColor White
    Write-Host "  .\run-docker-mosquitto.ps1 -Action stop" -ForegroundColor DarkGray
    Write-Host "  .\run-docker-mosquitto.ps1 -Action start" -ForegroundColor DarkGray
    Write-Host "  .\run-docker-mosquitto.ps1 -Action restart" -ForegroundColor DarkGray
    Write-Host "  .\run-docker-mosquitto.ps1 -Action status" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "Direct Docker commands:" -ForegroundColor White
    Write-Host "  docker stats mosquitto-broker" -ForegroundColor DarkGray
    Write-Host "  docker exec -it mosquitto-broker sh" -ForegroundColor DarkGray
}

# Main execution
try {
    # Check prerequisites
    Test-Prerequisites

    # Check Docker environment
    $composeVersion = Test-DockerEnvironment
    Write-VerboseMsg "Using Docker Compose: $composeVersion"

    # Verify directory structure
    Test-DirectoryStructure

    # Check for docker-compose.yml
    if (-not (Test-DockerComposeFile)) {
        exit 1
    }

    # Execute requested action
    switch ($Action) {
        "start" {
            Stop-Containers -ComposeVersion $composeVersion
            Start-MosquittoContainer -ComposeVersion $composeVersion

            if (-not $DryRun) {
                Test-MQTTConnectivity
                Show-ConnectionInfo
                Show-ManagementCommands

                Write-Host ""
                Write-Success "Deployment complete!"
                Write-Success "MQTT broker is running at localhost:1883"
                Write-Success "Management Center at http://localhost:8088"

                if (-not $NoLogs) {
                    Write-Host ""
                    Write-Info "Showing logs (Ctrl+C to exit)..."
                    Start-Sleep -Seconds 2
                    Show-Logs -ComposeVersion $composeVersion
                }
            }
        }
        "stop" {
            Stop-Containers -ComposeVersion $composeVersion
            Write-Success "Mosquitto stopped"
        }
        "restart" {
            Stop-Containers -ComposeVersion $composeVersion
            Start-MosquittoContainer -ComposeVersion $composeVersion

            if (-not $DryRun) {
                Write-Success "Mosquitto restarted"
                Test-MQTTConnectivity

                if (-not $NoLogs) {
                    Write-Host ""
                    Write-Info "Showing logs (Ctrl+C to exit)..."
                    Start-Sleep -Seconds 2
                    Show-Logs -ComposeVersion $composeVersion
                }
            }
        }
        "status" {
            Show-Status -ComposeVersion $composeVersion
            Test-MQTTConnectivity
        }
        "logs" {
            Show-Logs -ComposeVersion $composeVersion
        }
        default {
            Write-ErrorMsg "Unknown action: $Action"
            exit 1
        }
    }

} catch {
    Write-Host ""
    Write-ErrorMsg "Script failed: $_"
    Write-Info "Run with -Verbose for more details"
    exit 1
}
