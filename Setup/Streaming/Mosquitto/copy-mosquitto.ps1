# PowerShell Script to Create MQTT Directory Structure
# Creates the required directory structure for Cedalo Mosquitto Docker container
# Author: Generated for MQTT deployment
# Date: $(Get-Date -Format "yyyy-MM-dd")

# Script configuration
$ErrorActionPreference = "Stop"
$BaseDir = "C:\Streaming\MQTT\mosquitto"

Write-Host "=== Creating MQTT Directory Structure ===" -ForegroundColor Green
Write-Host "Base directory: $BaseDir" -ForegroundColor Yellow

# Function to check if running as administrator
function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check for administrator privileges
if (-not (Test-Administrator)) {
    Write-Host "This script requires administrator privileges to create directories in C:\. Please run as administrator." -ForegroundColor Red
    exit 1
}

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
    
    Write-Host "Creating directory structure..." -ForegroundColor Yellow
    
    foreach ($dir in $directories) {
        try {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
                Write-Host "[+] Created: $dir" -ForegroundColor Green
                
                # Set permissions to allow Docker to access the directories
                $acl = Get-Acl $dir
                $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule("Everyone", "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
                $acl.SetAccessRule($accessRule)
                Set-Acl -Path $dir -AclObject $acl
                
            } else {
                Write-Host "[+] Already exists: $dir" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[-] Failed to create: $dir" -ForegroundColor Red
            Write-Host "Error: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# Function to create basic Mosquitto configuration file
function New-MosquittoConfigFile {
    param($ConfigPath)
    
    $configContent = @"
# Mosquitto Configuration File
# Basic configuration for Cedalo MQTT broker

# Network settings
listener 1883
listener 9001
protocol websockets

# Security settings
allow_anonymous true
# Uncomment and configure for authentication
# password_file /mosquitto/config/passwd
# acl_file /mosquitto/config/acl

# Logging configuration
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true

# Persistence settings
persistence true
persistence_location /mosquitto/data/
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
    
    $configFile = Join-Path $ConfigPath "mosquitto.conf"
    
    try {
        if (-not (Test-Path $configFile)) {
            $configContent | Out-File -FilePath $configFile -Encoding UTF8
            Write-Host "[+] Created Mosquitto configuration: $configFile" -ForegroundColor Green
        } else {
            Write-Host "[+] Configuration file already exists: $configFile" -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[-] Failed to create configuration file: $_" -ForegroundColor Red
        exit 1
    }
}

# Function to create a sample password file template
function New-PasswordFileTemplate {
    param($ConfigPath)
    
    $passwordTemplate = @"
# Mosquitto Password File Template
# To use authentication:
# 1. Uncomment the password_file line in mosquitto.conf
# 2. Add users with: mosquitto_passwd -c /mosquitto/config/passwd username
# 3. Or manually add users in format: username:password_hash
#
# Example:
# admin:`$6`$randomsalt`$hashedpassword
# user1:`$6`$randomsalt`$hashedpassword
"@
    
    $passwordFile = Join-Path $ConfigPath "passwd.template"
    
    try {
        if (-not (Test-Path $passwordFile)) {
            $passwordTemplate | Out-File -FilePath $passwordFile -Encoding UTF8
            Write-Host "[+] Created password file template: $passwordFile" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[-] Failed to create password template: $_" -ForegroundColor Red
    }
}

# Function to create ACL file template
function New-ACLFileTemplate {
    param($ConfigPath)
    
    $aclTemplate = @"
# Mosquitto ACL File Template
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
    
    try {
        if (-not (Test-Path $aclFile)) {
            $aclTemplate | Out-File -FilePath $aclFile -Encoding UTF8
            Write-Host "[+] Created ACL file template: $aclFile" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[-] Failed to create ACL template: $_" -ForegroundColor Red
    }
}

# Function to copy transformations folder
function Copy-TransformationsFolder {
    param($TargetPath)
    
    $sourcePath = "C:\Workshop--Data-Integration\Labs\Module 7 - Use Cases\Streaming Data\MQTT\transformations"
    $targetPath = Join-Path $TargetPath "transformations"
    
    Write-Host "Copying transformations folder..." -ForegroundColor Yellow
    
    try {
        if (Test-Path $sourcePath) {
            if (Test-Path $targetPath) {
                Write-Host "[+] Transformations folder already exists at: $targetPath" -ForegroundColor Yellow
            } else {
                Copy-Item -Path $sourcePath -Destination $targetPath -Recurse -Force
                Write-Host "[+] Copied transformations folder to: $targetPath" -ForegroundColor Green
            }
        } else {
            Write-Host "[!] Source transformations folder not found at: $sourcePath" -ForegroundColor Yellow
            Write-Host "    Skipping transformations copy. Please copy manually if needed." -ForegroundColor Yellow
        }
    }
    catch {
        Write-Host "[-] Failed to copy transformations folder: $_" -ForegroundColor Red
        Write-Host "    Please copy manually from: $sourcePath" -ForegroundColor Yellow
    }
}

# Function to copy Docker files
function Copy-DockerFiles {
    param($TargetPath)
    
    Write-Host "Copying Docker deployment files..." -ForegroundColor Yellow
    
    $filesToCopy = @(
        @{
            Name = "run-docker-mosquitto.ps1"
            Source = ".\run-docker-mosquitto.ps1"
        },
        @{
            Name = "docker-compose.yml"
            Source = ".\docker-compose.yml"
        }
    )
    
    foreach ($file in $filesToCopy) {
        $sourcePath = $file.Source
        $targetPath = Join-Path $TargetPath $file.Name
        
        try {
            if (Test-Path $sourcePath) {
                if (Test-Path $targetPath) {
                    Write-Host "[+] $($file.Name) already exists at target location" -ForegroundColor Yellow
                } else {
                    Copy-Item -Path $sourcePath -Destination $targetPath -Force
                    Write-Host "[+] Copied $($file.Name) to: $targetPath" -ForegroundColor Green
                }
            } else {
                Write-Host "[!] $($file.Name) not found in current directory: $sourcePath" -ForegroundColor Yellow
                Write-Host "    Please ensure $($file.Name) is in the same directory as this script." -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[-] Failed to copy $($file.Name): $_" -ForegroundColor Red
        }
    }
}

# Function to create a README file
function New-ReadmeFile {
    param($BasePath)
    
    $readmeContent = @"
# MQTT Cedalo Mosquitto Docker Setup

This directory contains the configuration and data files for the Cedalo Mosquitto MQTT broker.

## Directory Structure

- **config/**: Configuration files for Mosquitto
  - mosquitto.conf: Main configuration file
  - passwd.template: Password file template for authentication
  - acl.template: Access Control List template
- **data/**: Persistent data storage for MQTT messages
- **log/**: Log files from the Mosquitto broker
- **transformations/**: Data transformation scripts and configurations
- **run-docker-mosquitto.ps1**: Docker deployment script
- **docker-compose.yml**: Docker Compose configuration

## Usage

1. Run the setup script: ``.\create-mqtt-directories.ps1``
2. Deploy the container: ``.\run-docker-mosquitto.ps1``

## Configuration

Edit the ``config/mosquitto.conf`` file to customize:
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
1. Enable authentication by uncommenting password_file in mosquitto.conf
2. Create user accounts with mosquitto_passwd
3. Configure ACL rules for topic access control
4. Consider using TLS/SSL certificates

## Ports

- **1883**: MQTT protocol port
- **9001**: WebSocket port for web clients

## Created: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@
    
    $readmeFile = Join-Path $BasePath "README.md"
    
    try {
        if (-not (Test-Path $readmeFile)) {
            $readmeContent | Out-File -FilePath $readmeFile -Encoding UTF8
            Write-Host "[+] Created README file: $readmeFile" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "[-] Failed to create README file: $_" -ForegroundColor Red
    }
}

# Main execution
try {
    Write-Host "Starting directory creation process..." -ForegroundColor Yellow
    
    # Create main directory structure
    New-MQTTDirectoryStructure -BasePath $BaseDir
    
    # Create configuration files
    Write-Host "`nCreating configuration files..." -ForegroundColor Yellow
    New-MosquittoConfigFile -ConfigPath "$BaseDir\config"
    New-PasswordFileTemplate -ConfigPath "$BaseDir\config"
    New-ACLFileTemplate -ConfigPath "$BaseDir\config"
    
    # Copy transformations folder
    Write-Host "`nCopying transformations and Docker files..." -ForegroundColor Yellow
    Copy-TransformationsFolder -TargetPath $BaseDir
    Copy-DockerFiles -TargetPath $BaseDir
    
    # Create README file
    New-ReadmeFile -BasePath $BaseDir
    
    # Display summary
    Write-Host "`n=== Directory Structure Created ===" -ForegroundColor Green
    Write-Host "Base Directory: $BaseDir" -ForegroundColor White
    Write-Host "|-- config/" -ForegroundColor Cyan
    Write-Host "|   |-- mosquitto.conf" -ForegroundColor White
    Write-Host "|   |-- passwd.template" -ForegroundColor White
    Write-Host "|   +-- acl.template" -ForegroundColor White
    Write-Host "|-- data/" -ForegroundColor Cyan
    Write-Host "|-- log/" -ForegroundColor Cyan
    Write-Host "|-- transformations/" -ForegroundColor Cyan
    Write-Host "|-- run-docker-mosquitto.ps1" -ForegroundColor White
    Write-Host "|-- docker-compose.yml" -ForegroundColor White
    Write-Host "+-- README.md" -ForegroundColor White
    
    Write-Host "`n=== Next Steps ===" -ForegroundColor Green
    Write-Host "1. Review and customize the configuration in: $BaseDir\config\mosquitto.conf" -ForegroundColor White
    Write-Host "2. Change to the mosquitto directory: cd `"$BaseDir`"" -ForegroundColor White
    Write-Host "3. Run the Docker deployment script: .\run-docker-mosquitto.ps1" -ForegroundColor White
    Write-Host "4. Check the README.md file for additional information" -ForegroundColor White
    
    Write-Host "`n[+] Directory structure creation completed successfully!" -ForegroundColor Green
    
} catch {
    Write-Host "[-] Directory creation failed: $_" -ForegroundColor Red
    exit 1
}
