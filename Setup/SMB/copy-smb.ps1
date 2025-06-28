# Setup SMB Directories Script
# Creates C:\SMB directory structure with Bob, Alice, and Shared folders
# Populates with sample CSV data and copies workshop files
# Author: Generated for SMB workshop setup

#Requires -RunAsAdministrator

param(
    [string]$SMBPath = "C:\SMB",
    [string]$WorkshopSource = "C:\Workshop--Data-Integration\Setup\SMB",
    [string[]]$Users = @("Bob", "Alice"),
    [string]$SharedFolderName = "Shared",
    [switch]$Force  # Overwrite existing directory
)

# Function to create directory if it doesn't exist
function New-DirectoryIfNotExists {
    param([string]$Path)
    
    if (!(Test-Path -Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "  [DIR] Created: $Path" -ForegroundColor Green
    } else {
        Write-Host "  [DIR] Exists: $Path" -ForegroundColor Yellow
    }
}

# Function to create sample CSV data files
function New-SampleCSVFiles {
    param(
        [string]$BasePath,
        [string[]]$Users,
        [string]$SharedFolderName
    )
    
    Write-Host "Creating sample CSV data files..." -ForegroundColor Cyan
    
    # Bob's sales data
    $bobSalesData = @"
Date,Product,Quantity,Price,Customer,Region
2024-01-15,Laptop,2,1200.00,TechCorp,North
2024-01-16,Mouse,10,25.00,OfficeSupply Inc,South
2024-01-17,Keyboard,5,75.00,StartupXYZ,East
2024-01-18,Monitor,3,300.00,TechCorp,North
2024-01-19,Headset,8,120.00,CallCenter Ltd,West
2024-01-20,Webcam,4,80.00,RemoteWork Co,Central
2024-01-21,Printer,1,450.00,SmallBiz Corp,South
2024-01-22,Scanner,2,200.00,DocumentFlow,East
"@
    
    # Alice's employee data
    $aliceEmployeeData = @"
EmployeeID,FirstName,LastName,Department,Salary,HireDate,Status
101,John,Smith,Engineering,75000,2023-03-15,Active
102,Sarah,Johnson,Marketing,65000,2023-05-20,Active
103,Mike,Brown,Sales,70000,2023-01-10,Active
104,Lisa,Davis,HR,60000,2023-07-01,Active
105,Tom,Wilson,Engineering,78000,2023-04-12,Active
106,Emma,Garcia,Finance,72000,2023-06-08,Active
107,David,Miller,Sales,68000,2023-08-15,Active
108,Ashley,Taylor,Marketing,63000,2023-09-01,On Leave
"@
    
    # Shared project data
    $sharedProjectData = @"
ProjectID,ProjectName,Status,StartDate,EndDate,Budget,Manager,Priority
PRJ001,Website Redesign,In Progress,2024-01-01,2024-03-31,50000,Alice,High
PRJ002,Mobile App,Planning,2024-02-15,2024-08-15,120000,Bob,Medium
PRJ003,Database Migration,Completed,2023-10-01,2023-12-31,75000,Alice,High
PRJ004,Security Audit,On Hold,2024-01-20,2024-04-20,30000,Bob,Low
PRJ005,Cloud Migration,In Progress,2024-01-05,2024-06-30,200000,Alice,Critical
PRJ006,API Development,Planning,2024-03-01,2024-07-15,85000,Bob,Medium
"@
    
    # Shared reference codes
    $sharedReferenceData = @"
Category,Code,Description,Active
DEPT,ENG,Engineering Department,Yes
DEPT,MKT,Marketing Department,Yes
DEPT,SAL,Sales Department,Yes
DEPT,HR,Human Resources,Yes
DEPT,FIN,Finance Department,Yes
STATUS,ACTIVE,Currently Active,Yes
STATUS,INACTIVE,Not Active,Yes
STATUS,PENDING,Awaiting Approval,Yes
STATUS,ONHOLD,Temporarily Suspended,Yes
PRIORITY,LOW,Low Priority,Yes
PRIORITY,MEDIUM,Medium Priority,Yes
PRIORITY,HIGH,High Priority,Yes
PRIORITY,CRITICAL,Critical Priority,Yes
"@
    
    try {
        # Create CSV files for each user
        foreach ($User in $Users) {
            $userPath = Join-Path -Path $BasePath -ChildPath $User
            
            if ($User -eq "Bob") {
                $csvPath = Join-Path -Path $userPath -ChildPath "sales-data.csv"
                $bobSalesData | Out-File -FilePath $csvPath -Encoding UTF8
                Write-Host "  [OK] Created sales-data.csv in Bob's folder" -ForegroundColor Green
                
                # Additional file for Bob
                $monthlySalesData = @"
Month,TotalSales,Target,Achievement
January,125000,120000,104.2%
February,98000,110000,89.1%
March,145000,130000,111.5%
"@
                $monthlyPath = Join-Path -Path $userPath -ChildPath "monthly-sales.csv"
                $monthlySalesData | Out-File -FilePath $monthlyPath -Encoding UTF8
                Write-Host "  [OK] Created monthly-sales.csv in Bob's folder" -ForegroundColor Green
                
            } elseif ($User -eq "Alice") {
                $csvPath = Join-Path -Path $userPath -ChildPath "employee-data.csv"
                $aliceEmployeeData | Out-File -FilePath $csvPath -Encoding UTF8
                Write-Host "  [OK] Created employee-data.csv in Alice's folder" -ForegroundColor Green
                
                # Additional file for Alice
                $departmentData = @"
Department,HeadCount,Budget,Location
Engineering,25,2500000,Building A
Marketing,12,800000,Building B
Sales,18,1200000,Building C
HR,8,600000,Building B
Finance,10,700000,Building A
"@
                $deptPath = Join-Path -Path $userPath -ChildPath "department-summary.csv"
                $departmentData | Out-File -FilePath $deptPath -Encoding UTF8
                Write-Host "  [OK] Created department-summary.csv in Alice's folder" -ForegroundColor Green
            }
        }
        
        # Create files in shared folder
        $sharedPath = Join-Path -Path $BasePath -ChildPath $SharedFolderName
        
        # Project data
        $projectCsvPath = Join-Path -Path $sharedPath -ChildPath "project-data.csv"
        $sharedProjectData | Out-File -FilePath $projectCsvPath -Encoding UTF8
        Write-Host "  [OK] Created project-data.csv in Shared folder" -ForegroundColor Green
        
        # Reference codes
        $referenceCsvPath = Join-Path -Path $sharedPath -ChildPath "reference-codes.csv"
        $sharedReferenceData | Out-File -FilePath $referenceCsvPath -Encoding UTF8
        Write-Host "  [OK] Created reference-codes.csv in Shared folder" -ForegroundColor Green
        
        # Additional shared file - company contacts
        $contactsData = @"
ContactID,Name,Department,Email,Phone,Role
C001,Jane Wilson,IT,jane.wilson@company.com,555-0101,IT Manager
C002,Mark Johnson,Facilities,mark.johnson@company.com,555-0102,Facilities Manager
C003,Susan Brown,Legal,susan.brown@company.com,555-0103,Legal Counsel
C004,Robert Davis,Security,robert.davis@company.com,555-0104,Security Officer
"@
        $contactsPath = Join-Path -Path $sharedPath -ChildPath "company-contacts.csv"
        $contactsData | Out-File -FilePath $contactsPath -Encoding UTF8
        Write-Host "  [OK] Created company-contacts.csv in Shared folder" -ForegroundColor Green
        
    } catch {
        Write-Warning "Error creating sample CSV files: $($_.Exception.Message)"
    }
}

# Function to copy workshop files
function Copy-WorkshopFiles {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )
    
    Write-Host "Checking for workshop files at: $SourcePath" -ForegroundColor Cyan
    
    if (-not (Test-Path $SourcePath)) {
        Write-Warning "Workshop source directory does not exist: $SourcePath"
        Write-Host "Continuing without workshop files..." -ForegroundColor Yellow
        return $false
    }
    
    try {
        $sourceItems = Get-ChildItem -Path $SourcePath -ErrorAction SilentlyContinue
        
        if ($sourceItems) {
            Write-Host "Copying workshop files from $SourcePath..." -ForegroundColor Green
            
            # Copy all contents recursively
            Copy-Item -Path "$SourcePath\*" -Destination $DestinationPath -Recurse -Force -ErrorAction Stop
            
            # Verify copy operation
            $sourceCount = (Get-ChildItem -Path $SourcePath -Recurse -File | Measure-Object).Count
            $destCount = (Get-ChildItem -Path $DestinationPath -Recurse -File | Measure-Object).Count
            
            if ($destCount -ge $sourceCount) {
                Write-Host "  [OK] Workshop files copied successfully ($destCount files)" -ForegroundColor Green
            } else {
                Write-Warning "  [WARN] Copy verification: Expected $sourceCount files, found $destCount"
            }
            
            # Display copied items
            Write-Host "Workshop items copied:" -ForegroundColor Cyan
            Get-ChildItem -Path $DestinationPath | Where-Object { $_.Name -notin @("Bob", "Alice", $SharedFolderName) } | ForEach-Object {
                $itemType = if ($_.PSIsContainer) { "[DIR]" } else { "[FILE]" }
                Write-Host "  $itemType $($_.Name)" -ForegroundColor Gray
            }
            
            return $true
        } else {
            Write-Host "No workshop files found to copy." -ForegroundColor Yellow
            return $false
        }
    } catch {
        Write-Warning "Error copying workshop files: $($_.Exception.Message)"
        return $false
    }
}

# Function to display directory structure
function Show-DirectoryStructure {
    param([string]$BasePath)
    
    Write-Host "`n[DIR] Final SMB Directory Structure:" -ForegroundColor Blue
    Write-Host "$BasePath" -ForegroundColor White
    
    $allItems = Get-ChildItem -Path $BasePath -ErrorAction SilentlyContinue | Sort-Object Name
    
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
                    Write-Host "      |-- $($subItem.Name)" -ForegroundColor Gray
                }
            }
        } else {
            Write-Host "  |-- $($item.Name)" -ForegroundColor White
        }
    }
}

# ===================================================================
# MAIN SCRIPT EXECUTION
# ===================================================================

Write-Host "=== SMB Directory Setup Script ===" -ForegroundColor Magenta
Write-Host "SMB Path: $SMBPath" -ForegroundColor White
Write-Host "Workshop Source: $WorkshopSource" -ForegroundColor White
Write-Host "Users: $($Users -join ', ')" -ForegroundColor White
Write-Host "Shared Folder: $SharedFolderName" -ForegroundColor White
Write-Host ""

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script requires Administrator privileges. Please run as Administrator."
    exit 1
}

# Check if SMB directory already exists
if ((Test-Path $SMBPath) -and -not $Force) {
    $response = Read-Host "SMB directory already exists at $SMBPath. Overwrite? (y/N)"
    if ($response -ne 'y' -and $response -ne 'Y') {
        Write-Host "Operation cancelled." -ForegroundColor Yellow
        exit 0
    }
}

try {
    # Step 1: Create base SMB directory
    Write-Host "1. Creating base SMB directory..." -ForegroundColor Blue
    New-DirectoryIfNotExists -Path $SMBPath
    
    # Step 2: Create user and shared directories
    Write-Host "`n2. Creating user and shared directories..." -ForegroundColor Blue
    foreach ($User in $Users) {
        $userPath = Join-Path -Path $SMBPath -ChildPath $User
        New-DirectoryIfNotExists -Path $userPath
    }
    
    $sharedPath = Join-Path -Path $SMBPath -ChildPath $SharedFolderName
    New-DirectoryIfNotExists -Path $sharedPath
    
    # Step 3: Create sample CSV data
    Write-Host "`n3. Creating sample CSV data files..." -ForegroundColor Blue
    New-SampleCSVFiles -BasePath $SMBPath -Users $Users -SharedFolderName $SharedFolderName
    
    # Step 4: Copy workshop files (if they exist)
    Write-Host "`n4. Copying workshop files..." -ForegroundColor Blue
    $workshopFilesCopied = Copy-WorkshopFiles -SourcePath $WorkshopSource -DestinationPath $SMBPath
    
    # Step 5: Display final structure
    Show-DirectoryStructure -BasePath $SMBPath
    
    # Final summary
    Write-Host "`n[SUCCESS] SMB directory setup completed successfully!" -ForegroundColor Green
    
    if ($workshopFilesCopied) {
        Write-Host "[SUCCESS] Workshop files copied from: $WorkshopSource" -ForegroundColor Green
    }
    
    Write-Host "`n[SUMMARY] Report:" -ForegroundColor Yellow
    $totalFiles = (Get-ChildItem -Path $SMBPath -Recurse -File | Measure-Object).Count
    $totalDirs = (Get-ChildItem -Path $SMBPath -Recurse -Directory | Measure-Object).Count
    Write-Host "  • Total directories: $totalDirs" -ForegroundColor White
    Write-Host "  • Total files: $totalFiles" -ForegroundColor White
    Write-Host "  • Sample CSV files: Created for data integration testing" -ForegroundColor White
    Write-Host "  • Ready for SMB sharing or Docker deployment" -ForegroundColor White
    
    Write-Host "`n[NEXT] Next Steps:" -ForegroundColor Cyan
    Write-Host "  • Use Windows SMB sharing to share these folders" -ForegroundColor White
    Write-Host "  • Or use Docker deployment script to containerize" -ForegroundColor White
    Write-Host "  • Connect from applications using file paths or SMB URLs" -ForegroundColor White
    
} catch {
    Write-Error "Script execution failed: $($_.Exception.Message)"
    exit 1
}