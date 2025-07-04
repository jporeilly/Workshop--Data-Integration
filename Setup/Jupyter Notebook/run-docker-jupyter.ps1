# PowerShell script to run Jupyter Notebook in Docker
# Manages the Jupyter container defined in docker-compose.yml

param(
    [Parameter(Position=0)]
    [ValidateSet("start", "stop", "restart", "status", "logs", "shell", "cleanup", "help")]
    [string]$Action = "start",
    
    [string]$WorkingDirectory = "C:\Jupyter-Notebook",
    [switch]$Follow,
    [switch]$Force,
    [switch]$OpenBrowser
)

$workingDirectory = $WorkingDirectory

# Check if the directory exists
if (-not (Test-Path $workingDirectory)) {
    Write-Error "Directory does not exist: $workingDirectory"
    exit 1
}

# Check if docker-compose.yml exists in the scripts directory
$scriptsDir = Join-Path $workingDirectory "scripts"
$composeFile = Join-Path $scriptsDir "docker-compose.yml"
if (-not (Test-Path $composeFile)) {
    Write-Error "docker-compose.yml not found in: $scriptsDir"
    exit 1
}

# Check if Docker is installed and running
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

# Check if docker-compose is available
try {
    $composeVersion = docker-compose --version 2>$null
    if (-not $composeVersion) {
        # Try docker compose (newer syntax)
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

# Function to show help
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
    Write-Host "  -WorkingDirectory  Path to Jupyter directory (default: C:\Jupyter Notebook)"
    Write-Host "  -Follow           Follow log output (for logs action)"
    Write-Host "  -Force            Force operation (for cleanup action)"
    Write-Host "  -OpenBrowser      Open browser after start"
    Write-Host ""
    Write-Host "ACCESS POINT:" -ForegroundColor Yellow
    Write-Host "  Jupyter Lab: http://localhost:8888"
    Write-Host "  Token: datascience"
    Write-Host ""
    Write-Host "VOLUMES:" -ForegroundColor Yellow
    Write-Host "  Datasets: C:\Jupyter-Notebook\datasets"
    Write-Host "  Notebooks: C:\Jupyter-Notebook\notebooks"
    Write-Host "  PDI output: C:\Jupyter-Notebook\pdi-output"
    Write-Host "  Reports: C:\Jupyter-Notebook\reports"
    Write-Host "  Workshop data: C:\Jupyter-Notebook\workshop-data"
}

# Handle help action
if ($Action -eq "help") {
    Show-Help
    exit 0
}

try {
    # Change to the scripts directory where docker-compose.yml is located
    $scriptsDir = Join-Path $workingDirectory "scripts"
    Write-Host "Changing to directory: $scriptsDir"
    Set-Location -Path $scriptsDir
    
    switch ($Action) {
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
                Write-Host "VOLUME MAPPINGS:" -ForegroundColor Cyan
                Write-Host "  Datasets: C:\Jupyter-Notebook\datasets"
                Write-Host "  Notebooks: C:\Jupyter-Notebook\notebooks"
                Write-Host "  PDI output: C:\Jupyter-Notebook\pdi-output"
                Write-Host "  Reports: C:\Jupyter-Notebook\reports"
                Write-Host "  Workshop data: C:\Jupyter-Notebook\workshop-data"
                Write-Host ""
                Write-Host "MANAGEMENT COMMANDS:" -ForegroundColor Cyan
                Write-Host "  Check status: $composeCommand ps"
                Write-Host "  View logs: $composeCommand logs"
                Write-Host "  Stop services: $composeCommand down"
                
                if ($OpenBrowser) {
                    Write-Host "Opening Jupyter Lab in browser..." -ForegroundColor Cyan
                    Start-Process "http://localhost:8888"
                }
            } else {
                Write-Error "Docker Compose failed to start. Exit code: $LASTEXITCODE"
                exit 1
            }
        }
        
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
        
        "status" {
            Write-Host "Checking Jupyter environment status..." -ForegroundColor Cyan
            & $composeCommand.Split() ps
        }
        
        "logs" {
            Write-Host "Displaying container logs..." -ForegroundColor Cyan
            if ($Follow) {
                Write-Host "Following logs (Press Ctrl+C to stop)..." -ForegroundColor Yellow
                & $composeCommand.Split() logs -f
            } else {
                & $composeCommand.Split() logs
            }
        }
        
        "shell" {
            Write-Host "Opening shell in Jupyter container..." -ForegroundColor Cyan
            Write-Host "Type 'exit' to return to PowerShell" -ForegroundColor Yellow
            docker exec -it jupyter-datascience /bin/bash
        }
        
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
    # Return to original directory
    Pop-Location -ErrorAction SilentlyContinue
}
