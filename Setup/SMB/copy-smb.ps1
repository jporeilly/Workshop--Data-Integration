# SMB Workshop Directory Setup and File Copy Script
# This script creates the SMB directory structure and copies files from the workshop

# Define paths
$WorkshopSource = "C:\Workshop--Data-Integration\Setup\SMB"
$SMBDestination = "C:\SMB"

# Check if source directory exists
if (-not (Test-Path $WorkshopSource)) {
    Write-Error "Source directory does not exist: $WorkshopSource"
    Write-Host "Please ensure the Workshop Data Integration setup directory exists at the specified path." -ForegroundColor Yellow
    exit 1
}

# Create SMB destination directory
Write-Host "Creating SMB destination directory: $SMBDestination" -ForegroundColor Green
New-Item -ItemType Directory -Path $SMBDestination -Force -ErrorAction SilentlyContinue | Out-Null

# Copy files and directories from workshop to SMB (if any exist)
Write-Host "Copying existing workshop files to $SMBDestination..." -ForegroundColor Green

try {
    # Copy all contents recursively if source has content
    $sourceItems = Get-ChildItem -Path $WorkshopSource -ErrorAction SilentlyContinue
    if ($sourceItems) {
        Copy-Item -Path "$WorkshopSource\*" -Destination $SMBDestination -Recurse -Force
        Write-Host "Existing workshop files copied successfully." -ForegroundColor Cyan
    } else {
        Write-Host "No existing files found in workshop source. Will create new structure." -ForegroundColor Yellow
    }
} catch {
    Write-Warning "Error copying existing files: $_"
    Write-Host "Continuing with new directory creation..." -ForegroundColor Yellow
}

# Create the shared directories structure in SMB destination
Write-Host "`nCreating shared directory structure in $SMBDestination..." -ForegroundColor Green

# Change to SMB destination directory
Push-Location $SMBDestination

# Define the shared directories to create
$SharedDirs = @(
    "shared-documents",
    "shared-media", 
    "shared-backups"
)

# Create each shared directory
foreach ($dir in $SharedDirs) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
    Write-Host "  Created: $dir" -ForegroundColor Cyan
}

# Create sample data for testing
Write-Host "`nCreating sample test data..." -ForegroundColor Green

# Add test files to documents
Write-Host "Adding sample documents..." -ForegroundColor Cyan
"Welcome to our company file server!" | Out-File -FilePath "shared-documents\welcome.txt" -Encoding UTF8
"Project specifications and requirements" | Out-File -FilePath "shared-documents\project-specs.txt" -Encoding UTF8

# Create presentations folder and content
New-Item -ItemType Directory -Path "shared-documents\presentations" -Force | Out-Null
"Q1 Sales Report" | Out-File -FilePath "shared-documents\presentations\q1-report.txt" -Encoding UTF8

# Verify documents were created
Write-Host "`nDocuments created:" -ForegroundColor Yellow
Get-ChildItem "shared-documents" -Recurse

# Create media samples
Write-Host "`nCreating media structure..." -ForegroundColor Cyan
New-Item -ItemType Directory -Path "shared-media\images" -Force | Out-Null
New-Item -ItemType Directory -Path "shared-media\videos" -Force | Out-Null
"Sample image metadata" | Out-File -FilePath "shared-media\images\photo-info.txt" -Encoding UTF8

# Add a sample "large file" simulation
"This represents a large media file`n" * 100 | Out-File -FilePath "shared-media\videos\sample-video-metadata.txt" -Encoding UTF8

# Verify media structure
Write-Host "`nMedia structure created:" -ForegroundColor Yellow
Get-ChildItem "shared-media" -Recurse

# Return to original directory
Pop-Location

# Verify final copy operation
$allDestinationItems = Get-ChildItem -Path $SMBDestination -Recurse

Write-Host "`nCopy verification:" -ForegroundColor Yellow
Write-Host "  Total items in SMB destination: $($allDestinationItems.Count)" -ForegroundColor White

Write-Host "Copy and setup complete! Files and sample data created successfully in $SMBDestination" -ForegroundColor Green

# Display final SMB directory structure
Write-Host "`nFinal SMB directory structure:" -ForegroundColor Green
Write-Host "$SMBDestination" -ForegroundColor White
Get-ChildItem -Path $SMBDestination -Directory | ForEach-Object { 
    Write-Host "  |-- $($_.Name)" -ForegroundColor White
    # Show subdirectories if they exist
    $subDirs = Get-ChildItem -Path $_.FullName -Directory -ErrorAction SilentlyContinue
    foreach ($subDir in $subDirs) {
        Write-Host "      |-- $($subDir.Name)" -ForegroundColor Gray
    }
}

Write-Host "`nSMB workshop setup and file copy complete!" -ForegroundColor Green
Write-Host "You can now configure SMB sharing for the directories in $SMBDestination" -ForegroundColor Yellow