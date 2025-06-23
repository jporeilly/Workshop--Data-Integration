# PowerShell script to run docker-compose from C:\MySQL folder

$workingDirectory = "C:\MySQL"

# Check if the directory exists
if (-not (Test-Path $workingDirectory)) {
    Write-Error "Directory does not exist: $workingDirectory"
    exit 1
}

# Check if docker-compose.yml exists in the directory
$composeFile = Join-Path $workingDirectory "docker-compose.yml"
if (-not (Test-Path $composeFile)) {
    Write-Error "docker-compose.yml not found in: $workingDirectory"
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

try {
    Write-Host "Changing to directory: $workingDirectory"
    Set-Location -Path $workingDirectory
    
    Write-Host "Running $composeCommand up -d..."
    
    # Run docker-compose up in detached mode
    & $composeCommand.Split() up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Docker Compose started successfully!" -ForegroundColor Green
        Write-Host "You can check the status with: $composeCommand ps"
        Write-Host "To view logs, use: $composeCommand logs"
        Write-Host "To stop the services, use: $composeCommand down"
    } else {
        Write-Error "Docker Compose failed to start. Exit code: $LASTEXITCODE"
        exit 1
    }
}
catch {
    Write-Error "An error occurred while running Docker Compose: $_"
    exit 1
}
finally {
    # Return to original directory
    Pop-Location -ErrorAction SilentlyContinue
}