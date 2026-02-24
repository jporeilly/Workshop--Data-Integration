<#
.SYNOPSIS
    Creates MQTT directory structure for EMQX MQTT broker Docker deployment.

.DESCRIPTION
    This script creates the required directory structure and configuration files
    needed for running EMQX MQTT broker in Docker. It creates the
    directory structure, configuration files, templates, and copies necessary
    deployment files.

.PARAMETER BaseDir
    Base directory for MQTT installation. Default: $env:USERPROFILE\Streaming\mqtt

.PARAMETER Verbose
    Enable verbose output for detailed logging.

.PARAMETER DryRun
    Preview actions without making changes.

.PARAMETER Force
    Force overwrite existing files.

.PARAMETER SkipTransformations
    Skip copying transformations folder.

.PARAMETER Help
    Show help message.

.EXAMPLE
    .\copy-emqx.ps1
    Creates directory structure using default settings.

.EXAMPLE
    .\copy-emqx.ps1 -BaseDir "D:\MQTT\emqx"
    Creates directory structure at custom location.

.EXAMPLE
    .\copy-emqx.ps1 -DryRun
    Preview changes without actually creating anything.

.EXAMPLE
    .\copy-emqx.ps1 -Verbose -Force
    Create with verbose output and overwrite existing files.

.NOTES
    Version: 2.0
    Author: Generated for MQTT deployment
    Requires: Administrator privileges for system directories
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false, HelpMessage="Base directory for MQTT installation")]
    [string]$BaseDir = "$env:USERPROFILE\Streaming\mqtt",

    [Parameter(Mandatory=$false, HelpMessage="Enable verbose output")]
    [switch]$Verbose,

    [Parameter(Mandatory=$false, HelpMessage="Preview actions without making changes")]
    [switch]$DryRun,

    [Parameter(Mandatory=$false, HelpMessage="Force overwrite existing files")]
    [switch]$Force,

    [Parameter(Mandatory=$false, HelpMessage="Skip copying transformations folder")]
    [switch]$SkipTransformations,

    [Parameter(Mandatory=$false, HelpMessage="Show help message")]
    [switch]$Help
)

# Script configuration
$ErrorActionPreference = "Stop"
$ScriptVersion = "2.0"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Show help if requested
if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# Logging functions
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Cyan -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-ErrorMsg {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function Write-VerboseMsg {
    param([string]$Message)
    if ($Verbose) {
        Write-Host "[VERBOSE] " -ForegroundColor Blue -NoNewline
        Write-Host $Message
    }
}

function Write-DryRun {
    param([string]$Message)
    if ($DryRun) {
        Write-Host "[DRY-RUN] " -ForegroundColor Yellow -NoNewline
        Write-Host $Message
    }
}

# Display script header
Write-Host ""
Write-Host "=== EMQX MQTT Broker Setup Script v$ScriptVersion ===" -ForegroundColor Green

if ($DryRun) {
    Write-Warning "Running in DRY-RUN mode - no changes will be made"
}

Write-Host "Installation directory: " -NoNewline
Write-Host $BaseDir -ForegroundColor Yellow
Write-Host ""

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Validate prerequisites
function Test-Prerequisites {
    Write-VerboseMsg "Validating prerequisites..."

    # Check if base directory is in system drive and requires admin
    if ($BaseDir -match "^[A-Z]:\\(?!Users\\)" -and -not $DryRun) {
        if (-not (Test-Administrator)) {
            Write-ErrorMsg "Administrator privileges required for directory: $BaseDir"
            Write-Info "Please run as administrator or choose a directory in your user folder"
            exit 1
        }
    }

    # Validate base directory path
    if ([string]::IsNullOrWhiteSpace($BaseDir)) {
        Write-ErrorMsg "Base directory cannot be empty"
        exit 1
    }

    # Check if parent directory exists
    $parentDir = Split-Path -Parent $BaseDir
    if (-not $DryRun -and -not (Test-Path $parentDir)) {
        Write-ErrorMsg "Parent directory does not exist: $parentDir"
        exit 1
    }

    Write-VerboseMsg "Prerequisites validated successfully"
}

# Check prerequisites
Test-Prerequisites

# Function to create directory structure with proper permissions
function New-MQTTDirectoryStructure {
    param($BasePath)

    # Define all required directories
    $directories = @(
        $BasePath,
        "$BasePath\config",
        "$BasePath\data",
        "$BasePath\log"
    )

    Write-Info "Creating directory structure..."

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            if ($DryRun) {
                Write-DryRun "Would create: $dir"
            } else {
                try {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                    Write-Success "Created: $dir"

                    # Set permissions to allow Docker to access the directories
                    $acl = Get-Acl $dir
                    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                    $acl.SetAccessRule($accessRule)
                    Set-Acl -Path $dir -AclObject $acl
                    Write-VerboseMsg "Set permissions on: $dir"
                }
                catch {
                    Write-ErrorMsg "Failed to create: $dir"
                    Write-ErrorMsg "Error: $_"
                    throw
                }
            }
        } else {
            Write-Warning "Already exists: $dir"
        }
    }
}

# Function to create basic EMQX configuration file
function New-EMQXConfigFile {
    param($ConfigPath)

    $configContent = @"
# EMQX Configuration File
# Basic configuration for EMQX MQTT broker
# Generated by setup script

# Network settings
listener 1883
listener 9001
protocol websockets

# Security settings
allow_anonymous true
# Uncomment and configure for authentication
# password_file /emqx/config/passwd
# acl_file /emqx/config/acl

# Logging configuration
log_dest file /emqx/log/emqx.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true

# Persistence settings
persistence true
persistence_location /emqx/data/
autosave_interval 1800

# Connection settings
max_connections 1000
max_keepalive 300
keepalive_interval 60

# Queue settings
max_queued_messages 1000
message_size_limit 0

# Client settings
client_id_prefixes
max_inflight_messages 20
max_queued_messages 1000
"@

    $configFile = Join-Path $ConfigPath "emqx.conf"

    if (-not (Test-Path $configFile) -or $Force) {
        if ($DryRun) {
            Write-DryRun "Would create: $configFile"
        } else {
            try {
                $configContent | Out-File -FilePath $configFile -Encoding UTF8
                Write-Success "Created EMQX configuration: $configFile"
            }
            catch {
                Write-ErrorMsg "Failed to create configuration file: $_"
                throw
            }
        }
    } else {
        Write-Warning "Configuration file already exists: $configFile (use -Force to overwrite)"
    }
}

# Function to create a sample password file template
function New-PasswordFileTemplate {
    param($ConfigPath)

    $passwordTemplate = @"
# EMQX Password File Template
# To use authentication:
# 1. Uncomment the password_file line in emqx.conf
# 2. Add users with: mosquitto_passwd -c /emqx/config/passwd username
# 3. Or manually add users in format: username:password_hash
#
# Example:
# admin:`$6`$randomsalt`$hashedpassword
# user1:`$6`$randomsalt`$hashedpassword
"@

    $passwordFile = Join-Path $ConfigPath "passwd.template"

    if (-not (Test-Path $passwordFile) -or $Force) {
        if ($DryRun) {
            Write-DryRun "Would create: $passwordFile"
        } else {
            try {
                $passwordTemplate | Out-File -FilePath $passwordFile -Encoding UTF8
                Write-Success "Created password file template: $passwordFile"
            }
            catch {
                Write-ErrorMsg "Failed to create password template: $_"
            }
        }
    } else {
        Write-VerboseMsg "Password template already exists: $passwordFile"
    }
}

# Function to create ACL file template
function New-ACLFileTemplate {
    param($ConfigPath)

    $aclTemplate = @"
# EMQX ACL File Template
# Access Control List for MQTT topics
# Format: user username
#         topic [read|write|readwrite] topic
#
# Example:
# user admin
# topic readwrite #
#
# user sensor1
# topic write sensors/temperature/+
# topic read commands/sensor1
#
# pattern read sensors/%u/+
# pattern write sensors/%u/status
"@

    $aclFile = Join-Path $ConfigPath "acl.template"

    if (-not (Test-Path $aclFile) -or $Force) {
        if ($DryRun) {
            Write-DryRun "Would create: $aclFile"
        } else {
            try {
                $aclTemplate | Out-File -FilePath $aclFile -Encoding UTF8
                Write-Success "Created ACL file template: $aclFile"
            }
            catch {
                Write-ErrorMsg "Failed to create ACL template: $_"
            }
        }
    } else {
        Write-VerboseMsg "ACL template already exists: $aclFile"
    }
}

# Function to find transformations folder
function Find-TransformationsFolder {
    $possiblePaths = @(
        "$env:USERPROFILE\Workshop--Data-Integration\Labs\Module 7 - Use Cases\Streaming Data\MQTT\transformations",
        "C:\Workshop--Data-Integration\Labs\Module 7 - Use Cases\Streaming Data\MQTT\transformations",
        "D:\Workshop--Data-Integration\Labs\Module 7 - Use Cases\Streaming Data\MQTT\transformations",
        "$ScriptDir\..\..\Labs\Module 7 - Use Cases\Streaming Data\MQTT\transformations"
    )

    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# Function to copy transformations folder
function Copy-TransformationsFolder {
    param($TargetPath)

    if ($SkipTransformations) {
        Write-Info "Skipping transformations copy (-SkipTransformations flag)"
        return
    }

    Write-Info "Looking for transformations folder..."

    $sourcePath = Find-TransformationsFolder
    $targetFolder = Join-Path $TargetPath "transformations"

    if ($sourcePath) {
        Write-VerboseMsg "Found transformations at: $sourcePath"

        if ((Test-Path $targetFolder) -and -not $Force) {
            Write-Warning "Transformations folder already exists at: $targetFolder"
        } else {
            if ($DryRun) {
                Write-DryRun "Would copy: $sourcePath -> $targetFolder"
            } else {
                try {
                    Copy-Item -Path $sourcePath -Destination $targetFolder -Recurse -Force
                    Write-Success "Copied transformations folder to: $targetFolder"
                }
                catch {
                    Write-ErrorMsg "Failed to copy transformations folder: $_"
                    Write-Info "Please copy manually from: $sourcePath"
                }
            }
        }
    } else {
        Write-Warning "Source transformations folder not found"
        Write-Info "Checked common locations. Skipping transformations copy."
    }
}

# Function to copy Docker files
function Copy-DockerFiles {
    param($TargetPath)

    Write-Info "Copying Docker deployment files..."

    $filesToCopy = @(
        "run-docker-emqx.ps1",
        "cleanup-emqx.ps1",
        "docker-compose.yml"
    )

    foreach ($fileName in $filesToCopy) {
        $sourcePath = Join-Path $ScriptDir $fileName
        $targetFile = Join-Path $TargetPath $fileName

        if (Test-Path $sourcePath) {
            if ((Test-Path $targetFile) -and -not $Force) {
                Write-Warning "$fileName already exists at target location"
            } else {
                if ($DryRun) {
                    Write-DryRun "Would copy: $fileName -> $targetFile"
                } else {
                    try {
                        Copy-Item -Path $sourcePath -Destination $targetFile -Force
                        Write-Success "Copied $fileName to: $targetFile"
                    }
                    catch {
                        Write-ErrorMsg "Failed to copy ${fileName}: $_"
                    }
                }
            }
        } else {
            Write-ErrorMsg "$fileName not found in: $sourcePath"
            Write-Info "Please ensure $fileName is in the same directory as this script"
        }
    }
}

# Function to create a README file
function New-ReadmeFile {
    param($BasePath)

    $readmeContent = @"
# EMQX MQTT Broker Docker Setup

This directory contains the configuration and data files for the EMQX MQTT broker.

## Directory Structure

- **config/**: Configuration files for EMQX
  - emqx.conf: Main configuration file
  - passwd.template: Password file template for authentication
  - acl.template: Access Control List template
- **data/**: Persistent data storage for MQTT messages
- **log/**: Log files from the EMQX broker
- **transformations/**: Data transformation scripts and configurations
- **run-docker-emqx.ps1**: Docker deployment script
- **cleanup-emqx.ps1**: Cleanup/uninstall script
- **docker-compose.yml**: Docker Compose configuration

## Usage

1. Deploy the container: ``.\run-docker-emqx.ps1``
2. Access Dashboard: http://localhost:18083
   - Username: admin
   - Password: public

## Configuration

Edit the ``config/emqx.conf`` file to customize:
- Authentication settings
- Logging levels
- Connection limits
- Security options

## Transformations

The transformations folder contains:
- Data transformation scripts
- Configuration files for data processing
- Sample transformation examples

## Security

For production use:
1. Enable authentication by uncommenting password_file in emqx.conf
2. Create user accounts with mosquitto_passwd
3. Configure ACL rules for topic access control
4. Consider using TLS/SSL certificates
5. Change default Dashboard credentials

## Ports

- **1883**: MQTT protocol port
- **8083**: WebSocket port for web clients
- **18083**: Dashboard UI
- **8883**: MQTT over TLS (optional)

## Management Commands

``````powershell
# View logs
docker-compose logs -f

# Stop/start container
docker-compose stop
docker-compose start

# Restart container
docker-compose restart

# Remove container
docker-compose down

# Cleanup/uninstall (removes all data and configs)
.\cleanup-emqx.ps1
``````

## Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
## Installation Path: $BasePath
"@

    $readmeFile = Join-Path $BasePath "README.md"

    if (-not (Test-Path $readmeFile) -or $Force) {
        if ($DryRun) {
            Write-DryRun "Would create: $readmeFile"
        } else {
            try {
                $readmeContent | Out-File -FilePath $readmeFile -Encoding UTF8
                Write-Success "Created README file: $readmeFile"
            }
            catch {
                Write-ErrorMsg "Failed to create README file: $_"
            }
        }
    } else {
        Write-VerboseMsg "README already exists: $readmeFile"
    }
}

# Display summary
function Show-Summary {
    Write-Host ""
    Write-Host "=== Directory Structure ===" -ForegroundColor Green
    Write-Host "Base Directory: " -NoNewline
    Write-Host $BaseDir -ForegroundColor White
    Write-Host "|-- config/" -ForegroundColor Cyan
    Write-Host "|   |-- emqx.conf" -ForegroundColor White
    Write-Host "|   |-- passwd.template" -ForegroundColor White
    Write-Host "|   +-- acl.template" -ForegroundColor White
    Write-Host "|-- data/" -ForegroundColor Cyan
    Write-Host "|-- log/" -ForegroundColor Cyan
    Write-Host "|-- transformations/" -ForegroundColor Cyan
    Write-Host "|-- run-docker-emqx.ps1" -ForegroundColor White
    Write-Host "|-- cleanup-emqx.ps1" -ForegroundColor White
    Write-Host "|-- docker-compose.yml" -ForegroundColor White
    Write-Host "+-- README.md" -ForegroundColor White

    Write-Host ""
    Write-Host "=== Next Steps ===" -ForegroundColor Green
    Write-Host "1. Review configuration: " -NoNewline
    Write-Host "$BaseDir\config\emqx.conf" -ForegroundColor White
    Write-Host "2. Change directory: " -NoNewline
    Write-Host "cd `"$BaseDir`"" -ForegroundColor White
    Write-Host "3. Deploy container: " -NoNewline
    Write-Host ".\run-docker-emqx.ps1" -ForegroundColor White
    Write-Host "4. Access Dashboard: " -NoNewline
    Write-Host "http://localhost:18083" -ForegroundColor White
}

# Main execution
try {
    Write-Info "Starting directory creation process..."

    # Create main directory structure
    New-MQTTDirectoryStructure -BasePath $BaseDir

    # Create configuration files
    Write-Host ""
    Write-Info "Creating configuration files..."
    New-EMQXConfigFile -ConfigPath "$BaseDir\config"
    New-PasswordFileTemplate -ConfigPath "$BaseDir\config"
    New-ACLFileTemplate -ConfigPath "$BaseDir\config"

    # Copy transformations folder
    Write-Host ""
    Copy-TransformationsFolder -TargetPath $BaseDir

    # Copy Docker files
    Write-Host ""
    Copy-DockerFiles -TargetPath $BaseDir

    # Create README file
    Write-Host ""
    New-ReadmeFile -BasePath $BaseDir

    # Display summary
    if ($DryRun) {
        Write-Host ""
        Write-Warning "DRY-RUN complete. No actual changes were made."
        Write-Info "Run without -DryRun to apply changes"
    } else {
        Show-Summary
        Write-Host ""
        Write-Success "Setup completed successfully!"
    }

} catch {
    Write-Host ""
    Write-ErrorMsg "Script failed: $_"
    Write-Info "Run with -Verbose for more details"
    exit 1
}
