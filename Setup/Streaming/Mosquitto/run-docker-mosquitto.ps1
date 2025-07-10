# PowerShell Script to Run Cedalo Mosquitto Docker Container
# Deploys the Cedalo MQTT platform using docker-compose
# Author: Generated for MQTT deployment
# Date: $(Get-Date -Format "yyyy-MM-dd")

# Script configuration
$ErrorActionPreference = "Stop"
$BaseDir = "C:\Streaming\MQTT\mosquitto"
$DockerComposeFile = "docker-compose.yml"

Write-Host "=== Cedalo Mosquitto Docker Deployment ===" -ForegroundColor Green
Write-Host "Working directory: $BaseDir" -ForegroundColor Yellow

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Function to check Docker installation and status
function Test-DockerEnvironment {
    Write-Host "Checking Docker environment..." -ForegroundColor Yellow
    
    try {
        # Check if Docker is installed
        $dockerVersion = docker --version 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker not found in PATH"
        }
        Write-Host "[OK] Docker found: $dockerVersion" -ForegroundColor Green
        
        # Check if Docker is running
        docker ps >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] Docker is installed but not running." -ForegroundColor Red
            Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
            exit 1
        }
        Write-Host "[OK] Docker is running" -ForegroundColor Green
        
        # Check if docker-compose is available
        docker-compose --version >$null 2>&1
        if ($LASTEXITCODE -ne 0) {
            # Try docker compose (newer syntax)
            docker compose version >$null 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw "Docker Compose not available"
            }
            Write-Host "[OK] Docker Compose (v2) is available" -ForegroundColor Green
            return "v2"
        } else {
            Write-Host "[OK] Docker Compose (v1) is available" -ForegroundColor Green
            return "v1"
        }
    }
    catch {
        Write-Host "[ERROR] Docker environment check failed: $_" -ForegroundColor Red
        Write-Host "Please ensure Docker Desktop is installed and running." -ForegroundColor Yellow
        exit 1
    }
}

# Function to verify directory structure exists
function Test-DirectoryStructure {
    Write-Host "Verifying directory structure..." -ForegroundColor Yellow
    
    $requiredDirs = @(
        $BaseDir,
        "$BaseDir\config",
        "$BaseDir\data",
        "$BaseDir\log"
    )
    
    $missing = @()
    foreach ($dir in $requiredDirs) {
        if (-not (Test-Path $dir)) {
            $missing += $dir
        }
    }
    
    if ($missing.Count -gt 0) {
        Write-Host "[ERROR] Missing required directories:" -ForegroundColor Red
        foreach ($dir in $missing) {
            Write-Host "  - $dir" -ForegroundColor Red
        }
        Write-Host "Please run 'create-mqtt-directories.ps1' first." -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "[OK] Directory structure verified" -ForegroundColor Green
}

# Function to check if docker-compose.yml exists
function Test-DockerComposeFile {
    $composeFile = Join-Path $BaseDir $DockerComposeFile
    
    if (-not (Test-Path $composeFile)) {
        Write-Host "[ERROR] docker-compose.yml not found at: $composeFile" -ForegroundColor Red
        Write-Host "Please ensure the docker-compose.yml file is in the mosquitto directory." -ForegroundColor Yellow
        return $false
    }
    
    Write-Host "[OK] docker-compose.yml found" -ForegroundColor Green
    return $true
}

# Function to stop existing containers
function Stop-ExistingContainers {
    param($ComposeVersion, $WorkingDir)
    
    Write-Host "Checking for existing containers..." -ForegroundColor Yellow
    
    try {
        Set-Location $WorkingDir
        
        if ($ComposeVersion -eq "v2") {
            $containers = docker compose ps -q
        } else {
            $containers = docker-compose ps -q
        }
        
        if ($containers) {
            Write-Host "Stopping existing containers..." -ForegroundColor Yellow
            if ($ComposeVersion -eq "v2") {
                docker compose down
            } else {
                docker-compose down
            }
            Write-Host "[OK] Existing containers stopped" -ForegroundColor Green
        } else {
            Write-Host "[OK] No existing containers to stop" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[WARNING] Could not check for existing containers: $_" -ForegroundColor Yellow
    }
}

# Function to deploy the Mosquitto container
function Start-MosquittoContainer {
    param($ComposeVersion, $WorkingDir)
    
    try {
        Set-Location $WorkingDir
        Write-Host "Deploying Cedalo Mosquitto container..." -ForegroundColor Yellow
        
        # Pull the latest image
        Write-Host "Pulling latest Cedalo Mosquitto image..." -ForegroundColor Yellow
        if ($ComposeVersion -eq "v2") {
            docker compose pull
        } else {
            docker-compose pull
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to pull Docker image"
        }
        Write-Host "[OK] Image pulled successfully" -ForegroundColor Green
        
        # Start the container
        Write-Host "Starting Mosquitto container..." -ForegroundColor Yellow
        if ($ComposeVersion -eq "v2") {
            docker compose up -d
        } else {
            docker-compose up -d
        }
        
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to start container"
        }
        Write-Host "[OK] Container started successfully" -ForegroundColor Green
        
        # Wait for container to be ready
        Write-Host "Waiting for container to be ready..." -ForegroundColor Yellow
        Start-Sleep -Seconds 5
        
        # Check container status
        Write-Host "`nContainer Status:" -ForegroundColor Cyan
        if ($ComposeVersion -eq "v2") {
            docker compose ps
        } else {
            docker-compose ps
        }
        
        # Check if container is healthy
        $containerId = docker ps -q --filter "name=mosquitto-broker"
        if ($containerId) {
            Write-Host "[OK] Mosquitto broker is running (Container ID: $containerId)" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] Container may not be running properly" -ForegroundColor Yellow
        }
        
    }
    catch {
        Write-Host "[ERROR] Error deploying container: $_" -ForegroundColor Red
        Write-Host "Checking logs..." -ForegroundColor Yellow
        
        if ($ComposeVersion -eq "v2") {
            docker compose logs
        } else {
            docker-compose logs
        }
        exit 1
    }
}

# Function to test MQTT connectivity
function Test-MQTTConnectivity {
    Write-Host "Testing MQTT connectivity..." -ForegroundColor Yellow
    
    try {
        # Test if ports are listening
        $mqttPort = Test-NetConnection -ComputerName localhost -Port 1883 -InformationLevel Quiet -WarningAction SilentlyContinue
        $wsPort = Test-NetConnection -ComputerName localhost -Port 9001 -InformationLevel Quiet -WarningAction SilentlyContinue
        
        if ($mqttPort) {
            Write-Host "[OK] MQTT port 1883 is accessible" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] MQTT port 1883 is not accessible" -ForegroundColor Yellow
        }
        
        if ($wsPort) {
            Write-Host "[OK] WebSocket port 9001 is accessible" -ForegroundColor Green
        } else {
            Write-Host "[WARNING] WebSocket port 9001 is not accessible" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[WARNING] Could not test connectivity: $_" -ForegroundColor Yellow
    }
}

# Function to display connection information
function Show-ConnectionInfo {
    Write-Host "`n=== Connection Information ===" -ForegroundColor Cyan
    Write-Host "MQTT Broker:" -ForegroundColor White
    Write-Host "  Host: localhost" -ForegroundColor White
    Write-Host "  Port: 1883" -ForegroundColor White
    Write-Host "  Protocol: MQTT" -ForegroundColor White
    Write-Host ""
    Write-Host "WebSocket Connection:" -ForegroundColor White
    Write-Host "  Host: localhost" -ForegroundColor White
    Write-Host "  Port: 9001" -ForegroundColor White
    Write-Host "  Protocol: WebSocket" -ForegroundColor White
    Write-Host ""
    Write-Host "Configuration:" -ForegroundColor White
    Write-Host "  Config File: $BaseDir\config\mosquitto.conf" -ForegroundColor White
    Write-Host "  Data Directory: $BaseDir\data" -ForegroundColor White
    Write-Host "  Log Directory: $BaseDir\log" -ForegroundColor White
}

# Function to display management commands
function Show-ManagementCommands {
    Write-Host "`n=== Management Commands ===" -ForegroundColor Cyan
    Write-Host "View logs:" -ForegroundColor White
    Write-Host "  docker-compose logs -f" -ForegroundColor Gray
    Write-Host "  docker-compose logs mosquitto" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Container management:" -ForegroundColor White
    Write-Host "  docker-compose stop" -ForegroundColor Gray
    Write-Host "  docker-compose start" -ForegroundColor Gray
    Write-Host "  docker-compose restart" -ForegroundColor Gray
    Write-Host "  docker-compose down" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Status and monitoring:" -ForegroundColor White
    Write-Host "  docker-compose ps" -ForegroundColor Gray
    Write-Host "  docker stats mosquitto-broker" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Access container shell:" -ForegroundColor White
    Write-Host "  docker exec -it mosquitto-broker sh" -ForegroundColor Gray
}

# Main execution
try {
    Write-Host "Starting Mosquitto deployment process..." -ForegroundColor Yellow
    
    # Check if running as administrator (recommended for Docker operations)
    if (-not (Test-Administrator)) {
        Write-Host "[WARNING] Not running as administrator. Some operations may fail." -ForegroundColor Yellow
        Write-Host "Consider running as administrator if you encounter issues." -ForegroundColor Yellow
    }
    
    # Check Docker environment
    $composeVersion = Test-DockerEnvironment
    
    # Verify directory structure
    Test-DirectoryStructure
    
    # Check for docker-compose.yml
    if (-not (Test-DockerComposeFile)) {
        exit 1
    }
    
    # Stop any existing containers
    Stop-ExistingContainers -ComposeVersion $composeVersion -WorkingDir $BaseDir
    
    # Deploy the container
    Start-MosquittoContainer -ComposeVersion $composeVersion -WorkingDir $BaseDir
    
    # Test connectivity
    Test-MQTTConnectivity
    
    # Display connection information
    Show-ConnectionInfo
    
    # Show management commands
    Show-ManagementCommands
    
    Write-Host "`n=== Deployment Complete ===" -ForegroundColor Green
    Write-Host "[OK] Cedalo Mosquitto MQTT broker is now running!" -ForegroundColor Green
    Write-Host "[OK] You can now connect MQTT clients to localhost:1883" -ForegroundColor Green
    Write-Host "[OK] WebSocket clients can connect to localhost:9001" -ForegroundColor Green
    
} catch {
    Write-Host "[ERROR] Deployment failed: $_" -ForegroundColor Red
    exit 1
}
