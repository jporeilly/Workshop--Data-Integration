# PowerShell script to edit kettlekettle.properties file with nano

# Get the current user's home directory
$userHome = $env:USERPROFILE

# Define the file path
$filePath = Join-Path $userHome ".kettle\kettle.properties"

# Check if nano is available
try {
    Get-Command nano -ErrorAction Stop | Out-Null
    Write-Host "Found nano editor" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: nano is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Please install nano first using: scoop install nano" -ForegroundColor Yellow
    exit 1
}

# Check if the file exists, if not create it
if (-not (Test-Path $filePath)) {
    Write-Host "File does not exist. Creating: $filePath" -ForegroundColor Yellow
    try {
        New-Item -Path $filePath -ItemType File -Force | Out-Null
        Write-Host "Created empty file: $filePath" -ForegroundColor Green
    }
    catch {
        Write-Host "ERROR: Could not create file: $filePath" -ForegroundColor Red
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# Display file info
Write-Host "Editing file: $filePath" -ForegroundColor Cyan
Write-Host "File size: $((Get-Item $filePath).Length) bytes" -ForegroundColor Gray

# Open the file in nano
Write-Host "Opening nano editor..." -ForegroundColor Green
Write-Host "Press Ctrl+X to exit nano" -ForegroundColor Yellow

try {
    & nano $filePath
    Write-Host "nano editor closed successfully" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Failed to open nano" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}