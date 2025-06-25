# SMB Server Setup Script
param(
    [ValidateSet("help", "start", "stop", "status", "connect", "clean")]
    [string]$Action = "help",
    [switch]$Verbose
)

function Test-DockerCompose {
    try {
        docker-compose --version > $null
        return $true
    } catch {
        return $false
    }
}

function Start-SMBServer {
    Write-Host "Starting SMB Server..." -ForegroundColor Green
    
    # Check if Docker is running
    docker info 2>$null
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Docker is not running. Please start Docker Desktop first." -ForegroundColor Red
        return
    }
    
    # Check if docker-compose is available
    if (-not (Test-DockerCompose)) {
        Write-Host "docker-compose not found. Please install Docker Desktop with docker-compose." -ForegroundColor Red
        return
    }
    
    # Start the SMB server
    Write-Host "Starting Docker container..." -ForegroundColor Yellow
    try {
        docker-compose up -d
        
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SMB Server started successfully!" -ForegroundColor Green
            Write-Host "Connection Information:" -ForegroundColor Cyan
            Write-Host "Server: \\localhost:1445" -ForegroundColor White
            Write-Host "Users:" -ForegroundColor White
            Write-Host "  - bob (password: password)" -ForegroundColor White
            Write-Host "  - alice (password: password)" -ForegroundColor White
            
            if ($Verbose) {
                Write-Host "`nAvailable Shares & Permissions:" -ForegroundColor Cyan
                Write-Host "  \\localhost:1445\shared-backups    - Bob & Alice (Read/Write)" -ForegroundColor White
                Write-Host "  \\localhost:1445\shared-documents  - Bob & Alice (Read/Write)" -ForegroundColor White
                Write-Host "  \\localhost:1445\shared-media      - Alice (R/W), Bob (Read-Only)" -ForegroundColor White
                Write-Host "  \\localhost:1445\presentations     - Bob only (Read/Write)" -ForegroundColor White
            }
            
            Write-Host "Run '.\run-docker-smb.ps1 -Action connect' for connection examples" -ForegroundColor Cyan
        } else {
            Write-Host "Failed to start SMB server. Check Docker logs with: docker-compose logs samba" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error starting SMB server: $($_)" -ForegroundColor Red
    }
}

function Stop-SMBServer {
    Write-Host "Stopping SMB Server..." -ForegroundColor Yellow
    
    # Check if docker-compose is available
    if (-not (Test-DockerCompose)) {
        Write-Host "docker-compose not found. Please install Docker Desktop with docker-compose." -ForegroundColor Red
        return
    }
    
    try {
        docker-compose down
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SMB Server stopped successfully." -ForegroundColor Green
        } else {
            Write-Host "Error stopping SMB server." -ForegroundColor Red
        }
    } catch {
        Write-Host "Error stopping SMB server: $($_)" -ForegroundColor Red
    }
}

function Show-SMBStatus {
    Write-Host "SMB Server Status:" -ForegroundColor Cyan
    
    # Check if docker-compose is available
    if (-not (Test-DockerCompose)) {
        Write-Host "docker-compose not found. Please install Docker Desktop with docker-compose." -ForegroundColor Red
        return
    }
    
    try {
        docker-compose ps
        
        Write-Host "`nRecent Container Logs:" -ForegroundColor Cyan
        docker-compose logs --tail=15 samba
        
        # Add connection testing
        Write-Host "`nConnection Test:" -ForegroundColor Cyan
        $testResult = Test-NetConnection -ComputerName "localhost" -Port 1445 -WarningAction SilentlyContinue
        if ($testResult.TcpTestSucceeded) {
            Write-Host "SMB port 1445 is accessible on localhost" -ForegroundColor Green
        } else {
            Write-Host "SMB port 1445 is not accessible on localhost" -ForegroundColor Red
        }
    } catch {
        Write-Host "Error checking SMB status: $($_)" -ForegroundColor Red
    }
}

function Show-ConnectionHelp {
    Write-Host "SMB Connection Examples:" -ForegroundColor Cyan
    Write-Host "Connect as Bob:" -ForegroundColor Green
    Write-Host "net use Z: \\localhost:1445\shared-backups /user:bob" -ForegroundColor White
    Write-Host "net use Y: \\localhost:1445\shared-documents /user:bob" -ForegroundColor White
    Write-Host "net use X: \\localhost:1445\presentations /user:bob" -ForegroundColor White
    Write-Host "net use W: \\localhost:1445\shared-media /user:bob" -ForegroundColor White
    
    Write-Host "Connect as Alice:" -ForegroundColor Green  
    Write-Host "net use V: \\localhost:1445\shared-backups /user:alice" -ForegroundColor White
    Write-Host "net use U: \\localhost:1445\shared-documents /user:alice" -ForegroundColor White
    Write-Host "net use T: \\localhost:1445\shared-media /user:alice" -ForegroundColor White
    
    Write-Host "Disconnect all mapped drives:" -ForegroundColor Yellow
    Write-Host "net use * /delete /y" -ForegroundColor White
}

function Show-Help {
    Write-Host ""
    Write-Host "SMB Server Management Script" -ForegroundColor Cyan
    Write-Host "------------------------" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Usage: .\run-docker-smb.ps1 -Action [action] [-Verbose]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Actions:" -ForegroundColor Cyan
    Write-Host "  start    - Start the SMB Docker container" -ForegroundColor White
    Write-Host "  stop     - Stop the SMB Docker container" -ForegroundColor White
    Write-Host "  status   - Show container status and logs" -ForegroundColor White
    Write-Host "  connect  - Show connection examples" -ForegroundColor White
    Write-Host "  clean    - Remove containers, volumes and reset environment" -ForegroundColor White
    Write-Host "  help     - Show this help information" -ForegroundColor White
    Write-Host ""
    Write-Host "Options:" -ForegroundColor Cyan
    Write-Host "  -Verbose - Show additional information" -ForegroundColor White
}

function Reset-SMBServer {
    Write-Host "Cleaning up SMB server environment..." -ForegroundColor Yellow
    
    # Check if docker-compose is available
    if (-not (Test-DockerCompose)) {
        Write-Host "docker-compose not found. Please install Docker Desktop with docker-compose." -ForegroundColor Red
        return
    }
    
    try {
        # Remove containers and volumes
        docker-compose down -v
        Write-Host "Cleanup complete." -ForegroundColor Green
    } catch {
        Write-Host "Error cleaning up SMB environment: $($_)" -ForegroundColor Red
    }
}

# Main script with minimal syntax
if ($Action -eq "start") { Start-SMBServer }
if ($Action -eq "stop") { Stop-SMBServer }
if ($Action -eq "status") { Show-SMBStatus }
if ($Action -eq "connect") { Show-ConnectionHelp }
if ($Action -eq "clean") { Reset-SMBServer }
if ($Action -eq "help") { Show-Help }