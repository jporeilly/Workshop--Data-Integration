# Jupyter-Notebook Setup Script with Tree View and Docker Support
# Creates directories, copies files, and shows directory tree
param(
    [string]$SourcePath = "C:\\Workshop--Data-Integration\\Setup\\Jupyter-Notebook",
    [string]$DestinationPath = "C:\\Jupyter-Notebook",
    [switch]$Force,
    [switch]$Verify
)

function New-DirectoryIfNotExists {
    param([string]$Path)
    if (!(Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "  Created: $Path" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  Exists: $Path" -ForegroundColor Yellow
        return $false
    }
}

function Copy-SalesData {
    param([string]$SourcePath, [string]$DestinationPath)
    
    $sourceFile = Join-Path $SourcePath "sales_data.csv"
    $destFile = Join-Path $DestinationPath "sales_data.csv"
    
    if (Test-Path $sourceFile) {
        try {
            Copy-Item -Path $sourceFile -Destination $destFile -Force -ErrorAction Stop
            Write-Host "  Copied sales_data.csv to $destFile" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  Failed to copy sales_data.csv: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  Source file not found: $sourceFile" -ForegroundColor Yellow
        return $false
    }
}

function Copy-NotebookFile {
    param([string]$SourcePath, [string]$DestinationPath)
    
    $sourceFile = Join-Path $SourcePath "sales_analysis.ipynb"
    $destFile = Join-Path $DestinationPath "sales_analysis.ipynb"
    
    if (Test-Path $sourceFile) {
        try {
            Copy-Item -Path $sourceFile -Destination $destFile -Force -ErrorAction Stop
            Write-Host "  Copied sales_analysis.ipynb to $destFile" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  Failed to copy sales_analysis.ipynb: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  Source file not found: $sourceFile" -ForegroundColor Yellow
        return $false
    }
}

function Copy-ScriptFile {
    param([string]$SourcePath, [string]$DestinationPath)
    
    $sourceFile = Join-Path $SourcePath "file_watcher.py"
    $destFile = Join-Path $DestinationPath "file_watcher.py"
    
    if (Test-Path $sourceFile) {
        try {
            Copy-Item -Path $sourceFile -Destination $destFile -Force -ErrorAction Stop
            Write-Host "  Copied file_watcher.py to $destFile" -ForegroundColor Green
            return $true
        } catch {
            Write-Host "  Failed to copy file_watcher.py: $_" -ForegroundColor Red
            return $false
        }
    } else {
        Write-Host "  Source file not found: $sourceFile" -ForegroundColor Yellow
        return $false
    }
}

function New-DockerDirectories {
    param([string]$BasePath)
    Write-Host "Creating Docker volume directories..." -ForegroundColor Cyan
    
    $workshopDataPath = Join-Path $BasePath "workshop-data"
    New-DirectoryIfNotExists -Path $workshopDataPath
    
    $pdiOutputPath = Join-Path $BasePath "pdi-output"
    New-DirectoryIfNotExists -Path $pdiOutputPath
    
    $notebooksPath = Join-Path $BasePath "notebooks"
    $datasetsPath = Join-Path $BasePath "datasets"
    $scriptsPath = Join-Path $BasePath "scripts"
    $reportsPath = Join-Path $BasePath "reports"
    
    New-DirectoryIfNotExists -Path $notebooksPath
    New-DirectoryIfNotExists -Path $datasetsPath
    New-DirectoryIfNotExists -Path $scriptsPath
    New-DirectoryIfNotExists -Path $reportsPath
    
    # Copy required files to their respective directories
    Write-Host "`nCopying sales data..." -ForegroundColor Cyan
    Copy-SalesData -SourcePath $PSScriptRoot -DestinationPath $datasetsPath
    
    Write-Host "`nCopying notebook files..." -ForegroundColor Cyan
    Copy-NotebookFile -SourcePath $PSScriptRoot -DestinationPath $notebooksPath
    
    Write-Host "`nCopying script files..." -ForegroundColor Cyan
    Copy-ScriptFile -SourcePath $PSScriptRoot -DestinationPath $scriptsPath
    
    # Create sample files in their respective directories
    $sampleNotebook = Join-Path $notebooksPath "welcome.ipynb"
    if (!(Test-Path $sampleNotebook)) {
        $notebookContent = @"
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Welcome to Jupyter Desktop Workshop Environment\n",
    "\n",
    "This is your main workspace directory.\n",
    "\n",
    "## Available Directories:\n",
    "- workshop-data/ - Main workspace\n",
    "- pdi-output/ - PDI processed files\n",
    "- notebooks/ - Additional notebooks\n",
    "- datasets/ - Data files\n",
    "- scripts/ - Python scripts\n",
    "- reports/ - Generated reports\n",
    "\n",
    "## Getting Started:\n",
    "1. Run docker-compose up\n",
    "2. Access Jupyter Lab at http://localhost:8888"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
"@
        $notebookContent | Out-File -FilePath $sampleNotebook -Encoding UTF8
        Write-Host "  Created sample notebook: welcome.ipynb" -ForegroundColor Green
    }
    
    $pdiReadme = Join-Path $pdiOutputPath "README.md"
    if (!(Test-Path $pdiReadme)) {
        $readmeContent = @"
# PDI Output Directory

This directory is mapped to /home/jovyan/pdi-data in the Docker container.

Use this directory for:
- Output files from Pentaho Data Integration (PDI) 
- Processed datasets
- ETL results
- Files shared between PDI (host) and Jupyter (container)

## Usage:
1. Configure PDI transformations to output files here
2. Access files from Jupyter using path /home/jovyan/pdi-data/
3. Process and analyze data using Python/pandas in Jupyter
"@
        $readmeContent | Out-File -FilePath $pdiReadme -Encoding UTF8
        Write-Host "  Created PDI README file" -ForegroundColor Green
    }
    
    return @{
        WorkshopData = $workshopDataPath
        PDIOutput = $pdiOutputPath
        Notebooks = $notebooksPath
        Datasets = $datasetsPath
        Scripts = $scriptsPath
        Reports = $reportsPath
    }
}

function Show-DirectoryTree {
    param([string]$Path)
    
    Write-Host "`nDirectory Tree:" -ForegroundColor Blue
    Write-Host "$Path" -ForegroundColor White
    
    $allItems = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Sort-Object Name
    
    foreach ($item in $allItems) {
        if ($item.PSIsContainer) {
            Write-Host "  |-- $($item.Name)/" -ForegroundColor Cyan
            
            $subItems = Get-ChildItem -Path $item.FullName -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($subItem in $subItems) {
                if ($subItem.PSIsContainer) {
                    Write-Host "      |-- $($subItem.Name)/" -ForegroundColor Gray
                    
                    $subFiles = Get-ChildItem -Path $subItem.FullName -File -ErrorAction SilentlyContinue | Sort-Object Name
                    foreach ($subFile in $subFiles) {
                        Write-Host "          |-- $($subFile.Name)" -ForegroundColor DarkGray
                    }
                } else {
                    $fileSize = ""
                    if ($subItem.Length -lt 1KB) {
                        $fileSize = " ($($subItem.Length) B)"
                    } elseif ($subItem.Length -lt 1MB) {
                        $fileSize = " ($([math]::Round($subItem.Length / 1KB, 1)) KB)"
                    } else {
                        $fileSize = " ($([math]::Round($subItem.Length / 1MB, 1)) MB)"
                    }
                    Write-Host "      |-- $($subItem.Name)$fileSize" -ForegroundColor Gray
                }
            }
        } else {
            $fileSize = ""
            if ($item.Length -lt 1KB) {
                $fileSize = " ($($item.Length) B)"
            } elseif ($item.Length -lt 1MB) {
                $fileSize = " ($([math]::Round($item.Length / 1KB, 1)) KB)"
            } else {
                $fileSize = " ($([math]::Round($item.Length / 1MB, 1)) MB)"
            }
            Write-Host "  |-- $($item.Name)$fileSize" -ForegroundColor White
        }
    }
}

# MAIN EXECUTION
Write-Host "=== Enhanced Jupyter Notebook Setup Script ===" -ForegroundColor Magenta
Write-Host "Source Path: $SourcePath" -ForegroundColor White
Write-Host "Destination Path: $DestinationPath" -ForegroundColor White
Write-Host ""

# Validate source path exists
if (!(Test-Path $SourcePath)) {
    Write-Error "Source path does not exist: $SourcePath"
    Write-Host "Please verify the source directory exists and try again." -ForegroundColor Yellow
    exit 1
}

# Check if destination directory already exists
if ((Test-Path $DestinationPath) -and -not $Force) {
    $response = Read-Host "Destination directory already exists at $DestinationPath. Overwrite? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

try {
    # Step 1: Create destination directory
    Write-Host "1. Creating destination directory..." -ForegroundColor Blue
    New-DirectoryIfNotExists -Path $DestinationPath
    
    # Step 2: Create Docker volume directories
    Write-Host "`n2. Creating Docker volume directories..." -ForegroundColor Blue
    $dockerDirs = New-DockerDirectories -BasePath $DestinationPath
    
    # Step 3: Copy files with proper directory structure
    Write-Host "`n3. Copying Jupyter Notebook files..." -ForegroundColor Blue
    
    # Define the files to copy and their destination directories
    $filesToCopy = @(
        @{ 
            Source = Join-Path $SourcePath "docker-compose.yml"
            Destination = Join-Path $DestinationPath "scripts"
        },
        @{ 
            Source = Join-Path $SourcePath "run-docker-jupyter.ps1"
            Destination = Join-Path $DestinationPath "scripts"
        },
        @{ 
            Source = Join-Path $SourcePath "welcome.ipynb"
            Destination = Join-Path $DestinationPath "notebooks"
        }
    )
    
    # Copy each file to its destination
    foreach ($file in $filesToCopy) {
        $destDir = $file.Destination
        if (!(Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        if (Test-Path $file.Source) {
            $fileName = Split-Path $file.Source -Leaf
            $destPath = Join-Path $destDir $fileName
            Copy-Item -Path $file.Source -Destination $destPath -Force
            Write-Host "  Copied: $($file.Source) -> $destPath" -ForegroundColor Green
        } else {
            Write-Host "  Warning: Source file not found: $($file.Source)" -ForegroundColor Yellow
        }
    }
    Write-Host "  Copy operation completed successfully" -ForegroundColor Green

    # Step 4: Show directory tree
    Write-Host "`n4. Displaying directory structure..." -ForegroundColor Blue
    Show-DirectoryTree -Path $DestinationPath
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`nSetup Complete! Your Jupyter Notebook environment is ready." -ForegroundColor Magenta
}