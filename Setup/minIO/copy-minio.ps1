# PowerShell script to copy MinIO files
# Source: C:\Workshop--Data-Integration\Setup\MinIO\*
# Destination: C:\MinIO

$sourcePath = "C:\Workshop--Data-Integration\Setup\MinIO\*"
$destinationPath = "C:\MinIO"

# Check if source directory exists
if (-not (Test-Path "C:\Workshop--Data-Integration\Setup\MinIO")) {
    Write-Error "Source directory does not exist: C:\Workshop--Data-Integration\Setup\MinIO"
    exit 1
}

# Create destination directory if it doesn't exist
if (-not (Test-Path $destinationPath)) {
    Write-Host "Creating destination directory: $destinationPath"
    New-Item -ItemType Directory -Path $destinationPath -Force
}

try {
    Write-Host "Copying files from $sourcePath to $destinationPath..."
    
    # Copy all files and subdirectories recursively
    Copy-Item -Path $sourcePath -Destination $destinationPath -Recurse -Force
    
    Write-Host "Copy operation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An error occurred during the copy operation: $_"
    exit 1
}