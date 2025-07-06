# Pentaho Data Integration Setup Script
# Checks Java 18+, downloads PDI if needed, and sets up installation

Write-Host "=== Pentaho Data Integration Setup Script ===" -ForegroundColor Green
Write-Host ""

# Function to check Java version
function Test-JavaVersion {
    try {
        $javaVersion = & java -version 2>&1
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        
        # Extract version number from java -version output
        $versionLine = $javaVersion | Select-String "version" | Select-Object -First 1
        if ($versionLine -match '"(\d+)\.(\d+)\.(\d+)_(\d+)"' -or 
            $versionLine -match '"(\d+)\.(\d+)\.(\d+)"' -or 
            $versionLine -match '"(\d+)"') {
            $majorVersion = [int]$matches[1]
            if ($majorVersion -ge 18) {
                Write-Host "[OK] Java $majorVersion detected - meets minimum requirement (Java 18+)" -ForegroundColor Green
                return $true
            } else {
                Write-Host "[X] Java $majorVersion detected - requires Java 18 or above" -ForegroundColor Red
                return $false
            }
        } else {
            Write-Host "[X] Unable to parse Java version" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[X] Java not found or not accessible" -ForegroundColor Red
        return $false
    }
}

# Function to find PDI file in Downloads
function Find-PDIFile {
    $downloadsPath = [Environment]::GetFolderPath("UserProfile") + "\Downloads"
    $pdiPattern = "pdi-ce-10.*.zip"
    
    Write-Host "Searching for PDI file in: $downloadsPath" -ForegroundColor Yellow
    
    $pdiFiles = Get-ChildItem -Path $downloadsPath -Filter $pdiPattern -ErrorAction SilentlyContinue
    
    if ($pdiFiles.Count -gt 0) {
        $latestFile = $pdiFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        Write-Host "[OK] Found PDI file: $($latestFile.Name)" -ForegroundColor Green
        return $latestFile.FullName
    } else {
        Write-Host "[X] No PDI file found matching pattern: $pdiPattern" -ForegroundColor Red
        return $null
    }
}

# Function to start Pentaho Data Integration
function Start-PentahoDI {
    param(
        [string]$installPath
    )
    
    try {
        $spoonPath = Join-Path $installPath "Spoon.bat"
        Write-Host "`nStarting Pentaho Data Integration (Spoon)..." -ForegroundColor Cyan
        
        if (Test-Path $spoonPath) {
            Start-Process -FilePath $spoonPath -WorkingDirectory $installPath
            Write-Host "[OK] Pentaho Data Integration (Spoon) is starting..." -ForegroundColor Green
            return $true
        } else {
            Write-Host "[X] Could not find Spoon.bat at: $spoonPath" -ForegroundColor Red
            return $false
        }
    }
    catch {
        Write-Host "[X] Error starting Pentaho Data Integration: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to extract and setup PDI
function Install-PDI {
    param(
        [string]$zipFilePath
    )
    
    $destinationPath = "C:\Pentaho\design-tools"
    
    try {
        # Create destination directory if it doesn't exist
        if (-not (Test-Path $destinationPath)) {
            Write-Host "Creating directory: $destinationPath" -ForegroundColor Yellow
            New-Item -ItemType Directory -Path $destinationPath -Force | Out-Null
        }
        
        # Extract ZIP file
        Write-Host "Extracting PDI archive..." -ForegroundColor Yellow
        
        # Use .NET method for extraction (works on PowerShell 5.0+)
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $tempExtractPath = "$env:TEMP\PDI_Extract_$(Get-Random)"
        
        [System.IO.Compression.ZipFile]::ExtractToDirectory($zipFilePath, $tempExtractPath)
        
        # Find the data-integration folder
        $dataIntegrationPath = Get-ChildItem -Path $tempExtractPath -Name "data-integration" -Recurse -Directory | Select-Object -First 1
        
        if ($dataIntegrationPath) {
            $sourcePath = Join-Path $tempExtractPath $dataIntegrationPath
            $targetPath = Join-Path $destinationPath "data-integration"
            
            Write-Host "Copying data-integration folder to: $targetPath" -ForegroundColor Yellow
            
            # Remove existing installation if present
            if (Test-Path $targetPath) {
                Write-Host "Removing existing installation..." -ForegroundColor Yellow
                Remove-Item -Path $targetPath -Recurse -Force
            }
            
            # Copy the data-integration folder
            Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
            
            # Clean up temporary extraction folder
            Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
            
            Write-Host "[OK] PDI installation completed successfully!" -ForegroundColor Green
            Write-Host "Installation location: $targetPath" -ForegroundColor Cyan
            
            # Store the installation path for later use
            $script:PDIInstallPath = $targetPath
            return $true
        } else {
            Write-Host "[X] Could not find data-integration folder in the extracted archive" -ForegroundColor Red
            Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
            return $false
        }
    }
    catch {
        Write-Host "[X] Error during installation: $($_.Exception.Message)" -ForegroundColor Red
        # Clean up on error
        Remove-Item -Path $tempExtractPath -Recurse -Force -ErrorAction SilentlyContinue
        return $false
    }
}

# Main execution
Write-Host "Step 1: Checking Java installation..." -ForegroundColor Cyan

if (-not (Test-JavaVersion)) {
    Write-Host ""
    Write-Host "Please download and install Java SE from:" -ForegroundColor Yellow
    Write-Host "https://download.oracle.com/java/24/latest/jdk-24_windows-x64_bin.exe" -ForegroundColor White
    Write-Host ""
    Write-Host "After installing Java, please restart your PowerShell session and run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 2: Checking for Pentaho Data Integration file..." -ForegroundColor Cyan

$pdiFile = Find-PDIFile

if (-not $pdiFile) {
    Write-Host ""
    Write-Host "You need to complete the form and download from:" -ForegroundColor Yellow
    Write-Host "https://pentaho.com/pentaho-developer-edition/" -ForegroundColor White
    Write-Host ""
    Write-Host "After downloading, please run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host ""
Write-Host "Step 3: Setting up Pentaho Data Integration..." -ForegroundColor Cyan

if (Install-PDI -zipFilePath $pdiFile) {
    Write-Host ""
    Write-Host "=== Setup completed successfully! ===" -ForegroundColor Green
    
    # Ask user if they want to start Pentaho Data Integration
    $startPDI = Read-Host "`nWould you like to start Pentaho Data Integration now? (Y/N)"
    
    if ($startPDI -eq 'Y' -or $startPDI -eq 'y') {
        Start-PentahoDI -installPath $script:PDIInstallPath
    } else {
        Write-Host "`nYou can start Pentaho Data Integration later by running: $($script:PDIInstallPath)\Spoon.bat" -ForegroundColor Cyan
    }
    
    exit 0
} else {
    Write-Host ""
    Write-Host "=== Setup failed! ===" -ForegroundColor Red
    exit 1
}
