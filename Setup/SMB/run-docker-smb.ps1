# Simple Docker SMB Server Script
# Manages SMB server deployment using Docker Compose

param(
    [ValidateSet("start", "stop", "status", "connect", "help")]
    [string]$Action = "help"
)

# Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$COMPOSE_FILE = Join-Path $SCRIPT_DIR "docker-compose.yml"
$CONTAINER_NAME = "smb-workshop-server"
$SMB_PORT = 1445
$NETBIOS_PORT = 1139
$SERVER_NAME = "localhost"

# User credentials
$USERS = @{
    "bob" = "password"
    "alice" = "password"
}

# Function to test if Docker Compose is available
function Test-DockerCompose {
    try {
        # Try legacy docker-compose first
        docker-compose --version > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            return "docker-compose"
        }
        
        # Try modern docker compose
        docker compose version > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            return "docker compose"
        }
        
        return $null
    } catch {
        return $null
    }
}

# Function to start the SMB server
function Start-SMBServer {
    Write-Host "Starting SMB Docker server..." -ForegroundColor Green
    
    # Check if docker-compose.yml exists
    if (!(Test-Path $COMPOSE_FILE)) {
        Write-Host "Error: docker-compose.yml not found at: $COMPOSE_FILE" -ForegroundColor Red
        return
    }
    
    # Check Docker Compose
    $composeCmd = Test-DockerCompose
    if (!$composeCmd) {
        Write-Host "Error: Docker Compose not found. Please install Docker Desktop." -ForegroundColor Red
        return
    }
    
    try {
        Set-Location $SCRIPT_DIR
        
        if ($composeCmd -eq "docker-compose") {
            docker-compose up -d
        } else {
            docker compose up -d
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SMB server started successfully!" -ForegroundColor Green
            Write-Host "Waiting for server to initialize..." -ForegroundColor Yellow
            Start-Sleep -Seconds 5
            Show-ConnectionInfo
        } else {
            Write-Host "Failed to start SMB server." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error starting SMB server: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to stop the SMB server
function Stop-SMBServer {
    Write-Host "Stopping SMB Docker server..." -ForegroundColor Yellow
    
    $composeCmd = Test-DockerCompose
    if (!$composeCmd) {
        Write-Host "Error: Docker Compose not found." -ForegroundColor Red
        return
    }
    
    try {
        Set-Location $SCRIPT_DIR
        
        if ($composeCmd -eq "docker-compose") {
            docker-compose down
        } else {
            docker compose down
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SMB server stopped successfully." -ForegroundColor Green
        } else {
            Write-Host "Error stopping SMB server." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error stopping SMB server: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to show server status
function Show-SMBStatus {
    Write-Host "SMB Server Status" -ForegroundColor Cyan
    Write-Host "=================" -ForegroundColor Cyan
    
    $composeCmd = Test-DockerCompose
    if (!$composeCmd) {
        Write-Host "Error: Docker Compose not found." -ForegroundColor Red
        return
    }
    
    try {
        Set-Location $SCRIPT_DIR
        
        # Container status
        Write-Host "`nContainer Status:" -ForegroundColor Yellow
        if ($composeCmd -eq "docker-compose") {
            docker-compose ps
        } else {
            docker compose ps
        }
        
        # Test ports
        Write-Host "`nPort Status:" -ForegroundColor Yellow
        $smbTest = Test-NetConnection -ComputerName $SERVER_NAME -Port $SMB_PORT -WarningAction SilentlyContinue
        $netbiosTest = Test-NetConnection -ComputerName $SERVER_NAME -Port $NETBIOS_PORT -WarningAction SilentlyContinue
        
        if ($smbTest.TcpTestSucceeded) {
            Write-Host "  SMB port ${SMB_PORT}: ACCESSIBLE" -ForegroundColor Green
        } else {
            Write-Host "  SMB port ${SMB_PORT}: NOT ACCESSIBLE" -ForegroundColor Red
        }
        
        if ($netbiosTest.TcpTestSucceeded) {
            Write-Host "  NetBIOS port ${NETBIOS_PORT}: ACCESSIBLE" -ForegroundColor Green
        } else {
            Write-Host "  NetBIOS port ${NETBIOS_PORT}: NOT ACCESSIBLE" -ForegroundColor Red
        }
        
        # Show connection info if running
        $containerRunning = docker ps --filter "name=$CONTAINER_NAME" --format "{{.Names}}" 2>$null
        if ($containerRunning) {
            Show-ConnectionInfo
        }
        
    } catch {
        Write-Host "Error checking status: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Function to show connection information
function Show-ConnectionInfo {
    Write-Host "`nSMB Connection Information" -ForegroundColor Cyan
    Write-Host "==========================" -ForegroundColor Cyan
    
    Write-Host "`nServer Details:" -ForegroundColor Yellow
    Write-Host "  Server: $SERVER_NAME" -ForegroundColor White
    Write-Host "  SMB Port: $SMB_PORT" -ForegroundColor White
    Write-Host "  NetBIOS Port: $NETBIOS_PORT" -ForegroundColor White
    
    Write-Host "`nUser Accounts:" -ForegroundColor Yellow
    foreach ($user in $USERS.Keys) {
        Write-Host "  Username: $user | Password: $($USERS[$user])" -ForegroundColor White
    }
    
    Write-Host "`nAvailable Shares:" -ForegroundColor Yellow
    Write-Host "  \\$SERVER_NAME\bob     - Bob's private files" -ForegroundColor White
    Write-Host "  \\$SERVER_NAME\alice   - Alice's private files" -ForegroundColor White
    Write-Host "  \\$SERVER_NAME\shared  - Shared team files" -ForegroundColor White
}

# Function to show connection examples
function Show-ConnectionExamples {
    Write-Host "`nSMB Connection Examples" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Cyan
    
    Write-Host "`nWindows File Explorer:" -ForegroundColor Green
    Write-Host "  1. Open File Explorer (Windows + E)" -ForegroundColor White
    Write-Host "  2. Type in address bar: \\$SERVER_NAME" -ForegroundColor White
    Write-Host "  3. Enter credentials when prompted" -ForegroundColor White
    
    Write-Host "`nCommand Line Examples:" -ForegroundColor Green
    Write-Host "  # Connect Bob's share:" -ForegroundColor Yellow
    Write-Host "  net use Z: \\$SERVER_NAME\bob /user:bob" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Connect Alice's share:" -ForegroundColor Yellow
    Write-Host "  net use Y: \\$SERVER_NAME\alice /user:alice" -ForegroundColor White
    Write-Host ""
    Write-Host "  # Connect shared folder:" -ForegroundColor Yellow
    Write-Host "  net use X: \\$SERVER_NAME\shared /user:bob" -ForegroundColor White
    
    Write-Host "`nWith passwords (non-interactive):" -ForegroundColor Green
    Write-Host "  net use Z: \\$SERVER_NAME\bob `"$($USERS.bob)`" /user:bob" -ForegroundColor White
    Write-Host "  net use Y: \\$SERVER_NAME\alice `"$($USERS.alice)`" /user:alice" -ForegroundColor White
    
    Write-Host "`nConnection Management:" -ForegroundColor Green
    Write-Host "  net use                # List current connections" -ForegroundColor White
    Write-Host "  net use Z: /delete     # Disconnect drive Z" -ForegroundColor White
    Write-Host "  net use * /delete /y   # Disconnect all drives" -ForegroundColor White
    
    Write-Host "`nTips:" -ForegroundColor Yellow
    Write-Host "  - Passwords are case-sensitive" -ForegroundColor Gray
    Write-Host "  - Port $SMB_PORT avoids Windows SMB conflicts" -ForegroundColor Gray
    Write-Host "  - Check Windows Firewall if connections fail" -ForegroundColor Gray
}

# Function to show help
function Show-Help {
    Write-Host ""
    Write-Host "Simple Docker SMB Server Script" -ForegroundColor Cyan
    Write-Host "===============================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\$($MyInvocation.MyCommand.Name) -Action [action]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  start    - Start the SMB Docker container" -ForegroundColor White
    Write-Host "  stop     - Stop the SMB Docker container" -ForegroundColor White
    Write-Host "  status   - Show server status and port connectivity" -ForegroundColor White
    Write-Host "  connect  - Show connection examples and commands" -ForegroundColor White
    Write-Host "  help     - Show this help information" -ForegroundColor White
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor Yellow
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -Action start" -ForegroundColor White
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -Action status" -ForegroundColor White
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -Action connect" -ForegroundColor White
    Write-Host "  .\$($MyInvocation.MyCommand.Name) -Action stop" -ForegroundColor White
    Write-Host ""
    Write-Host "Requirements:" -ForegroundColor Cyan
    Write-Host "  - Docker Desktop installed and running" -ForegroundColor Gray
    Write-Host "  - docker-compose.yml file in script directory" -ForegroundColor Gray
    Write-Host ""
}

# Main execution
switch ($Action.ToLower()) {
    "start"   { Start-SMBServer }
    "stop"    { Stop-SMBServer }
    "status"  { Show-SMBStatus }
    "connect" { Show-ConnectionExamples }
    "help"    { Show-Help }
    default   { Show-Help }
}