# =============================================================================
# JUPYTER NOTEBOOK SETUP SCRIPT (Windows / PowerShell)
# =============================================================================
#
# Purpose:
#   This script prepares the Jupyter Notebook environment on a Windows host by
#   creating the required directory structure under C:\Jupyter-Notebook, copying
#   workshop files (notebooks, datasets, scripts, Docker Compose config) into
#   their correct locations, and displaying a summary tree of the result.
#
# What it creates (destination layout):
#   C:\Jupyter-Notebook\
#   ├── datasets\           CSV data files used by notebooks
#   ├── notebooks\          Jupyter notebooks (.ipynb)
#   ├── pdi-output\         Landing zone for PDI transformation output
#   ├── reports\            Generated analysis reports (Excel/CSV)
#   ├── scripts\            Docker Compose, run script, Python helpers
#   └── workshop-data\      General-purpose workspace
#
# Prerequisites:
#   - Windows 10/11 with PowerShell 5.1 or later
#   - The workshop repository at C:\Workshop--Data-Integration
#
# Usage:
#   # Run with default paths
#   .\copy-jupyter.ps1
#
#   # Override source and destination paths
#   .\copy-jupyter.ps1 -SourcePath "D:\MySource" -DestinationPath "D:\MyJupyter"
#
#   # Skip the overwrite confirmation prompt
#   .\copy-jupyter.ps1 -Force
#
# Parameters:
#   -SourcePath       Path to the workshop setup directory (default: C:\Workshop--Data-Integration\Setup\Jupyter-Notebook)
#   -DestinationPath  Where to create the Jupyter environment (default: C:\Jupyter-Notebook)
#   -Force            Skip the "overwrite?" prompt if destination exists
#   -Verify           Reserved for future verification logic
#
# Related scripts:
#   run-docker-jupyter.ps1  Starts / stops the Jupyter Docker container
#   file_watcher.py         Watches pdi-output\ for new CSV files from PDI
# =============================================================================

param(
    [string]$SourcePath = "C:\\Workshop--Data-Integration\\Setup\\Jupyter-Notebook",
    [string]$DestinationPath = "C:\\Jupyter-Notebook",
    [switch]$Force,
    [switch]$Verify
)

# =============================================================================
# HELPER FUNCTION: New-DirectoryIfNotExists
# =============================================================================
# Creates a directory (and any missing parents) if it does not already exist.
# Returns $true when a new directory was created, $false when it already existed.
#
# Parameters:
#   -Path  Full path of the directory to create
# =============================================================================
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

# =============================================================================
# HELPER FUNCTION: Copy-SalesData
# =============================================================================
# Copies the sales_data.csv sample dataset from the source directory to the
# destination datasets directory.
#
# Parameters:
#   -SourcePath       The directory containing the source file
#   -DestinationPath  The directory to copy the file into
# =============================================================================
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

# =============================================================================
# HELPER FUNCTION: Copy-NotebookFile
# =============================================================================
# Copies the sales_analysis.ipynb notebook from the source directory to the
# destination notebooks directory. This is the main analysis notebook that
# runs inside the Jupyter container.
#
# Parameters:
#   -SourcePath       The directory containing the source file
#   -DestinationPath  The directory to copy the file into
# =============================================================================
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

# =============================================================================
# HELPER FUNCTION: Copy-ScriptFile
# =============================================================================
# Copies the file_watcher.py script from the source directory to the
# destination scripts directory. This Python script monitors the pdi-output\
# directory for new CSV files and notifies the user to run the notebook.
#
# Parameters:
#   -SourcePath       The directory containing the source file
#   -DestinationPath  The directory to copy the file into
# =============================================================================
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

# =============================================================================
# HELPER FUNCTION: New-DockerDirectories
# =============================================================================
# Creates all the sub-directories that will be bind-mounted into the Docker
# container, then copies the required workshop files into each directory:
#   - datasets\     <- sales_data.csv
#   - notebooks\    <- sales_analysis.ipynb, welcome.ipynb
#   - scripts\      <- file_watcher.py
#   - pdi-output\   <- README.md (created inline)
#   - reports\      (empty, receives output from notebooks)
#   - workshop-data\ (empty, general workspace)
#
# Parameters:
#   -BasePath  Root directory (e.g. C:\Jupyter-Notebook)
#
# Returns:
#   A hashtable mapping logical names to their full directory paths.
# =============================================================================
function New-DockerDirectories {
    param([string]$BasePath)
    Write-Host "Creating Docker volume directories..." -ForegroundColor Cyan

    # --- Create each sub-directory -------------------------------------------
    $workshopDataPath = Join-Path $BasePath "workshop-data"
    New-DirectoryIfNotExists -Path $workshopDataPath

    $pdiOutputPath = Join-Path $BasePath "pdi-output"
    New-DirectoryIfNotExists -Path $pdiOutputPath

    $notebooksPath = Join-Path $BasePath "notebooks"
    $datasetsPath = Join-Path $BasePath "datasets"
    $scriptsPath = Join-Path $BasePath "scripts"
    $reportsPath = Join-Path $BasePath "reports"
    $transformationsPath = Join-Path $BasePath "transformations"

    New-DirectoryIfNotExists -Path $notebooksPath
    New-DirectoryIfNotExists -Path $datasetsPath
    New-DirectoryIfNotExists -Path $scriptsPath
    New-DirectoryIfNotExists -Path $reportsPath
    New-DirectoryIfNotExists -Path $transformationsPath

    # --- Copy required files to their respective directories -----------------
    # $PSScriptRoot is the directory where this .ps1 file lives, which is
    # the windows/ folder inside the workshop repository. The CSV, notebook,
    # and Python files live one level up (the parent "Jupyter Notebook"
    # directory), so we resolve the parent path for all Copy-* calls.
    $parentDir = Split-Path $PSScriptRoot -Parent

    Write-Host "`nCopying sales data..." -ForegroundColor Cyan
    Copy-SalesData -SourcePath $parentDir -DestinationPath $datasetsPath

    # Copy orders.csv dataset
    $ordersSource = Join-Path $parentDir "orders.csv"
    $ordersDest = Join-Path $datasetsPath "orders.csv"
    if (Test-Path $ordersSource) {
        Copy-Item -Path $ordersSource -Destination $ordersDest -Force
        Write-Host "  Copied orders.csv to $ordersDest" -ForegroundColor Green
    } else {
        Write-Host "  Source file not found: $ordersSource" -ForegroundColor Yellow
    }

    Write-Host "`nCopying notebook files..." -ForegroundColor Cyan
    Copy-NotebookFile -SourcePath $parentDir -DestinationPath $notebooksPath

    Write-Host "`nCopying script files..." -ForegroundColor Cyan
    Copy-ScriptFile -SourcePath $parentDir -DestinationPath $scriptsPath

    # Copy the container startup script (auto-installs Python packages)
    $postStartSource = Join-Path $parentDir "post-start.sh"
    $postStartDest = Join-Path $scriptsPath "post-start.sh"
    if (Test-Path $postStartSource) {
        Copy-Item -Path $postStartSource -Destination $postStartDest -Force
        Write-Host "  Copied post-start.sh to $postStartDest" -ForegroundColor Green
    } else {
        Write-Host "  Source file not found: $postStartSource" -ForegroundColor Yellow
    }

    # --- Create the welcome.ipynb notebook if it doesn't already exist -------
    # This is a simple introductory notebook that lists the available
    # directories and getting-started instructions.
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

    # --- Create a README inside pdi-output\ explaining its purpose -----------
    $pdiReadme = Join-Path $pdiOutputPath "README.md"
    if (!(Test-Path $pdiReadme)) {
        $readmeContent = @"
# PDI Output Directory

This directory is mapped to /home/jovyan/pdi-output in the Docker container.

Use this directory for:
- Output files from Pentaho Data Integration (PDI)
- Processed datasets
- ETL results
- Files shared between PDI (host) and Jupyter (container)

## Usage:
1. Configure PDI transformations to output files here
2. Access files from Jupyter using path /home/jovyan/pdi-output/
3. Process and analyze data using Python/pandas in Jupyter
"@
        $readmeContent | Out-File -FilePath $pdiReadme -Encoding UTF8
        Write-Host "  Created PDI README file" -ForegroundColor Green
    }

    # --- Return a hashtable of all created directory paths -------------------
    return @{
        WorkshopData = $workshopDataPath
        PDIOutput = $pdiOutputPath
        Notebooks = $notebooksPath
        Datasets = $datasetsPath
        Scripts = $scriptsPath
        Reports = $reportsPath
    }
}

# =============================================================================
# HELPER FUNCTION: Show-DirectoryTree
# =============================================================================
# Displays a visual tree representation of the directory structure under the
# specified path, including file sizes. This gives the user a clear summary
# of everything that was created and copied.
#
# Parameters:
#   -Path  Root directory to display (e.g. C:\Jupyter-Notebook)
# =============================================================================
function Show-DirectoryTree {
    param([string]$Path)

    Write-Host "`nDirectory Tree:" -ForegroundColor Blue
    Write-Host "$Path" -ForegroundColor White

    # Get all top-level items sorted alphabetically
    $allItems = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Sort-Object Name

    foreach ($item in $allItems) {
        if ($item.PSIsContainer) {
            # --- This item is a directory ------------------------------------
            Write-Host "  |-- $($item.Name)/" -ForegroundColor Cyan

            # List items inside this directory (one level deeper)
            $subItems = Get-ChildItem -Path $item.FullName -ErrorAction SilentlyContinue | Sort-Object Name
            foreach ($subItem in $subItems) {
                if ($subItem.PSIsContainer) {
                    # Sub-directory (two levels deep)
                    Write-Host "      |-- $($subItem.Name)/" -ForegroundColor Gray

                    # Files inside the sub-directory (three levels deep)
                    $subFiles = Get-ChildItem -Path $subItem.FullName -File -ErrorAction SilentlyContinue | Sort-Object Name
                    foreach ($subFile in $subFiles) {
                        Write-Host "          |-- $($subFile.Name)" -ForegroundColor DarkGray
                    }
                } else {
                    # File with human-readable size
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
            # --- This item is a file (at the top level) ----------------------
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

# =============================================================================
# MAIN EXECUTION
# =============================================================================

Write-Host "=== Enhanced Jupyter Notebook Setup Script ===" -ForegroundColor Magenta
Write-Host "Source Path: $SourcePath" -ForegroundColor White
Write-Host "Destination Path: $DestinationPath" -ForegroundColor White
Write-Host ""

# --- Validate that the source directory exists --------------------------------
if (!(Test-Path $SourcePath)) {
    Write-Error "Source path does not exist: $SourcePath"
    Write-Host "Please verify the source directory exists and try again." -ForegroundColor Yellow
    exit 1
}

# --- Check if the destination already exists (prompt before overwriting) ------
if ((Test-Path $DestinationPath) -and -not $Force) {
    $response = Read-Host "Destination directory already exists at $DestinationPath. Overwrite? (y/N)"
    if ($response -ne "y" -and $response -ne "Y") {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

try {
    # =========================================================================
    # STEP 1: Create the top-level destination directory
    # =========================================================================
    Write-Host "1. Creating destination directory..." -ForegroundColor Blue
    New-DirectoryIfNotExists -Path $DestinationPath

    # =========================================================================
    # STEP 2: Create Docker volume directories and copy workshop files
    # =========================================================================
    # This single function call creates all sub-directories (datasets, notebooks,
    # pdi-output, reports, scripts, workshop-data) and copies the required files
    # (CSV data, notebooks, Python scripts) into their correct locations.
    # =========================================================================
    Write-Host "`n2. Creating Docker volume directories..." -ForegroundColor Blue
    $dockerDirs = New-DockerDirectories -BasePath $DestinationPath

    # =========================================================================
    # STEP 3: Copy additional files (docker-compose.yml, run script, welcome)
    # =========================================================================
    Write-Host "`n3. Copying Jupyter Notebook files..." -ForegroundColor Blue

    # Define the additional files to copy and their destination directories.
    # These files support the Docker container setup.
    $filesToCopy = @(
        @{
            # The Windows docker-compose.yml (with C:\ volume paths)
            Source = Join-Path $SourcePath "docker-compose.yml"
            Destination = Join-Path $DestinationPath "scripts"
        },
        @{
            # The PowerShell Docker management script
            Source = Join-Path $SourcePath "run-docker-jupyter.ps1"
            Destination = Join-Path $DestinationPath "scripts"
        },
        @{
            # The welcome notebook for the notebooks directory
            Source = Join-Path $SourcePath "welcome.ipynb"
            Destination = Join-Path $DestinationPath "notebooks"
        }
    )

    # Copy each file to its destination, creating the directory if needed
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

    # =========================================================================
    # STEP 4: Display the final directory tree
    # =========================================================================
    Write-Host "`n4. Displaying directory structure..." -ForegroundColor Blue
    Show-DirectoryTree -Path $DestinationPath
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    Write-Host "`nSetup Complete! Your Jupyter Notebook environment is ready." -ForegroundColor Magenta
}
