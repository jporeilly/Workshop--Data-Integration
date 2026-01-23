# MinIO Docker Deployment for Windows

This directory contains scripts and configuration to deploy MinIO as a Docker container on Windows using Docker Desktop.

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Files Description](#files-description)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Management](#management)
- [Data Persistence](#data-persistence)
- [Troubleshooting](#troubleshooting)
- [Security](#security)

## Overview

MinIO is a high-performance, S3-compatible object storage system. This deployment:
- Runs MinIO in a Docker container
- Exposes both API (port 9000) and Web Console (port 9002)
- Stores data in a persistent Docker volume
- Automatically restarts on failures or system reboots

## Prerequisites

### Required Software

1. **Windows 10/11** (64-bit)
   - Pro, Enterprise, or Education editions recommended for Hyper-V
   - Home edition requires WSL 2

2. **Docker Desktop for Windows** (latest version)
   - Download: https://www.docker.com/products/docker-desktop
   - Includes Docker Engine and Docker Compose
   - Minimum Requirements:
     - 4GB RAM (8GB recommended)
     - 64-bit processor with virtualization support
     - Hyper-V and Containers Windows features enabled (or WSL 2)

3. **PowerShell 5.1 or higher**
   - Included with Windows 10/11
   - Check version: `$PSVersionTable.PSVersion`

### System Configuration

Enable virtualization in BIOS if not already enabled:
- Intel: Enable VT-x
- AMD: Enable AMD-V

For Docker Desktop with Hyper-V:
- Windows Features: Hyper-V, Containers
- Enable via: Control Panel → Programs → Turn Windows features on or off

For Docker Desktop with WSL 2:
- Windows Features: Virtual Machine Platform, Windows Subsystem for Linux
- Install WSL 2 kernel update: https://aka.ms/wsl2kernel

## Files Description

### `docker-compose.yml`
Docker Compose configuration file that defines the MinIO service.

**Configuration Details:**
```yaml
services:
  minio:
    image: minio/minio:latest         # Uses latest MinIO image from Docker Hub
    container_name: minio             # Container named 'minio' for easy reference
    restart: always                   # Auto-restart on failure or reboot
    ports:
      - "9000:9000"                   # MinIO API port (S3-compatible)
      - "9002:9001"                   # MinIO Console (Web UI, mapped from 9001)
    environment:
      MINIO_ROOT_USER: minioadmin     # Default admin username (CHANGE THIS!)
      MINIO_ROOT_PASSWORD: minioadmin # Default admin password (CHANGE THIS!)
    volumes:
      - minio_data:/data              # Persistent storage volume
    command: server /data --console-address ":9001"  # Start server with console
```

**Key Points:**
- Port 9001 is MinIO's console port, mapped to host port 9002 to avoid conflicts
- Data stored in Docker-managed volume `minio_data` (not a directory)
- Container runs as server mode with web console enabled

### `copy-minio.ps1`
PowerShell script to copy deployment files from the repository to `C:\MinIO`.

**What it does:**
1. Validates source directory exists: `C:\Github\Workshop--Data-Integration\Setup\MinIO\windows`
2. Creates destination directory: `C:\MinIO`
3. Copies all files (docker-compose.yml, run-docker-minio.ps1, README.md)
4. Provides next steps guidance

**Usage:**
```powershell
.\copy-minio.ps1
```

### `run-docker-minio.ps1`
PowerShell script to validate environment and start MinIO container.

**What it does:**
1. Checks if `C:\MinIO` directory exists
2. Validates `docker-compose.yml` is present
3. Verifies Docker Desktop is installed and running
4. Detects Docker Compose version (V1 or V2 syntax)
5. Starts MinIO in detached mode (background)
6. Displays access URLs and credentials
7. Shows management commands

**Usage:**
```powershell
cd C:\MinIO
.\run-docker-minio.ps1
```

### `README.md`
This documentation file.

## Installation

### Step 1: Install Docker Desktop

1. Download Docker Desktop from https://www.docker.com/products/docker-desktop
2. Run the installer
3. Follow the installation wizard
4. Restart your computer if prompted
5. Start Docker Desktop
6. Wait for "Docker Desktop is running" notification (system tray)

**Verify installation:**
```powershell
docker --version
docker compose version
```

### Step 2: Clone or Access Repository

Ensure the repository is located at:
```
C:\Github\Workshop--Data-Integration\
```

If not, either:
- Clone the repository to this location, or
- Update the `$sourcePath` in `copy-minio.ps1` to match your repository location

### Step 3: Deploy MinIO

1. **Open PowerShell** (as Administrator recommended)

2. **Navigate to the Windows setup directory:**
   ```powershell
   cd C:\Github\Workshop--Data-Integration\Setup\MinIO\windows
   ```

3. **Run the copy script:**
   ```powershell
   .\copy-minio.ps1
   ```

   This copies files to `C:\MinIO`

4. **Navigate to deployment directory:**
   ```powershell
   cd C:\MinIO
   ```

5. **Start MinIO:**
   ```powershell
   .\run-docker-minio.ps1
   ```

6. **Wait for container to start** (first run downloads the image, ~200MB)

### Step 4: Verify Deployment

1. **Check container status:**
   ```powershell
   docker ps
   ```

   You should see a container named `minio` in the list

2. **Access MinIO Console:**
   - Open browser to: http://localhost:9002
   - Login with: `minioadmin` / `minioadmin`

3. **Test API endpoint:**
   ```powershell
   curl http://localhost:9000/minio/health/live
   ```

   Should return: `200 OK`

## Usage

### Accessing MinIO

**Web Console (Browser UI):**
- URL: http://localhost:9002
- Use for: Creating buckets, uploading files, managing users, viewing metrics

**API Endpoint (S3-Compatible):**
- URL: http://localhost:9000
- Use for: Programmatic access, SDK integration, AWS CLI

**Default Credentials:**
- Username: `minioadmin`
- Password: `minioadmin`
- **⚠️ IMPORTANT:** Change these immediately for any non-development use!

### Using MinIO Console

1. Navigate to http://localhost:9002
2. Login with credentials
3. Click "Buckets" → "Create Bucket" to create storage buckets
4. Upload files by clicking on a bucket and using "Upload" button
5. Manage access policies under "Identity" → "Users" and "Policies"

### Using AWS CLI with MinIO

Install AWS CLI, then configure:

```powershell
aws configure --profile minio
# AWS Access Key ID: minioadmin
# AWS Secret Access Key: minioadmin
# Default region name: us-east-1
# Default output format: json
```

Create a bucket:
```powershell
aws --profile minio --endpoint-url http://localhost:9000 s3 mb s3://my-bucket
```

Upload a file:
```powershell
aws --profile minio --endpoint-url http://localhost:9000 s3 cp file.txt s3://my-bucket/
```

List buckets:
```powershell
aws --profile minio --endpoint-url http://localhost:9000 s3 ls
```

## Configuration

### Changing Default Credentials

**IMPORTANT:** Change credentials before production use!

1. **Edit docker-compose.yml:**
   ```powershell
   cd C:\MinIO
   notepad docker-compose.yml
   ```

2. **Update environment variables:**
   ```yaml
   environment:
     MINIO_ROOT_USER: your_secure_username
     MINIO_ROOT_PASSWORD: your_secure_password_min_8_chars
   ```

   Requirements:
   - Username: 5-20 characters
   - Password: minimum 8 characters

3. **Save and restart:**
   ```powershell
   docker compose down
   docker compose up -d
   ```

### Changing Ports

If ports 9000 or 9002 are already in use:

1. **Edit docker-compose.yml:**
   ```yaml
   ports:
     - "9100:9000"   # API port (change 9100 to your preferred port)
     - "9102:9001"   # Console port (change 9102 to your preferred port)
   ```

2. **Restart container:**
   ```powershell
   docker compose down
   docker compose up -d
   ```

### Advanced Configuration

#### Enable TLS/HTTPS

1. Generate or obtain SSL certificates
2. Mount certificate directory:
   ```yaml
   volumes:
     - minio_data:/data
     - C:\MinIO\certs:/root/.minio/certs
   ```
3. Place `public.crt` and `private.key` in `C:\MinIO\certs`
4. Restart container

#### Resource Limits

Add resource constraints:
```yaml
services:
  minio:
    # ... existing config ...
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 2G
        reservations:
          memory: 1G
```

## Management

All commands should be run from `C:\MinIO` directory.

### Check Container Status

```powershell
# View running containers
docker ps

# View all containers (including stopped)
docker ps -a

# Using Docker Compose
docker compose ps
```

### View Logs

```powershell
# View all logs
docker compose logs

# Follow logs in real-time
docker compose logs -f

# View last 100 lines
docker compose logs --tail=100

# View logs for last hour
docker logs --since 1h minio
```

### Stop MinIO

```powershell
# Stop container (data is preserved)
docker compose down

# Stop container only (don't remove)
docker compose stop
```

### Start MinIO

```powershell
# Start existing container
docker compose start

# Or use the run script
.\run-docker-minio.ps1
```

### Restart MinIO

```powershell
# Restart container
docker compose restart

# Or stop and start
docker compose down
docker compose up -d
```

### Update MinIO

```powershell
# Pull latest image
docker compose pull

# Recreate container with new image
docker compose up -d

# View current version
docker exec minio minio --version
```

### Remove Everything

```powershell
# Stop and remove container (data preserved in volume)
docker compose down

# Remove container AND volume (DELETES ALL DATA)
docker compose down -v

# Remove volume manually
docker volume rm minio_data
```

## Data Persistence

### Understanding Docker Volumes

MinIO data is stored in a Docker-managed volume named `minio_data`:
- **Location:** Managed by Docker (not a regular folder)
- **Persistence:** Data survives container restarts, updates, and removals
- **Isolation:** Protected from accidental deletion

### Inspect Volume

```powershell
# View volume details
docker volume inspect minio_data

# Find volume location (Windows with WSL 2)
# Typically: \\wsl$\docker-desktop-data\data\docker\volumes\minio_data\_data
```

### Backup Data

**Method 1: Using Docker (Recommended)**
```powershell
# Create backup directory
mkdir C:\MinIO\backups

# Backup volume to tar file
docker run --rm -v minio_data:/data -v C:\MinIO\backups:/backup ubuntu tar czf /backup/minio-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss').tar.gz /data
```

**Method 2: Using MinIO Client (mc)**
```powershell
# Install MinIO Client
# Download from: https://min.io/docs/minio/windows/reference/minio-mc.html

# Configure alias
mc alias set local http://localhost:9000 minioadmin minioadmin

# Mirror all buckets
mc mirror local C:\MinIO\backups\buckets
```

### Restore Data

**From tar backup:**
```powershell
# Stop MinIO
docker compose down

# Restore volume
docker run --rm -v minio_data:/data -v C:\MinIO\backups:/backup ubuntu tar xzf /backup/minio-backup-20240123-120000.tar.gz -C /

# Start MinIO
docker compose up -d
```

**From MinIO Client backup:**
```powershell
mc mirror C:\MinIO\backups\buckets local
```

## Troubleshooting

### Docker Desktop Not Running

**Symptoms:**
- Error: "docker command not found"
- Error: "Cannot connect to Docker daemon"

**Solution:**
1. Open Docker Desktop from Start menu
2. Wait for status "Docker Desktop is running" (system tray)
3. Try command again

### Port Already in Use

**Symptoms:**
- Error: "port is already allocated"
- Error: "bind: address already in use"

**Solution:**
```powershell
# Find process using port 9000
netstat -ano | findstr :9000

# Kill process (replace PID with actual process ID)
taskkill /PID <PID> /F

# Or change ports in docker-compose.yml
```

### Container Fails to Start

**Check logs:**
```powershell
docker compose logs

# Or
docker logs minio
```

**Common issues:**
- Insufficient disk space: Free up space on C:\ drive
- Memory limits: Increase Docker Desktop memory allocation
- Corrupted volume: Try `docker compose down -v` and restart

### Cannot Access Web Console

**Check container is running:**
```powershell
docker ps
```

**Check if port is accessible:**
```powershell
# Test API port
curl http://localhost:9000/minio/health/live

# Test Console port
curl http://localhost:9002
```

**Firewall issues:**
1. Open Windows Defender Firewall
2. Allow Docker Desktop through firewall
3. Or temporarily disable to test

### Slow Performance

**Improve Docker Desktop performance:**
1. Open Docker Desktop → Settings → Resources
2. Increase CPUs (recommend 2-4)
3. Increase Memory (recommend 4-8 GB)
4. Enable WSL 2 backend if not already enabled

**Check disk usage:**
```powershell
# View Docker disk usage
docker system df

# Clean up unused resources
docker system prune -a
```

### PowerShell Execution Policy

**Symptoms:**
- Error: "cannot be loaded because running scripts is disabled"

**Solution:**
```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy to allow scripts (as Administrator)
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Or run script with bypass
powershell -ExecutionPolicy Bypass -File .\copy-minio.ps1
```

### Container Keeps Restarting

**Check logs:**
```powershell
docker logs minio --tail 50
```

**Common causes:**
- Invalid configuration in docker-compose.yml
- Conflicting container with same name
- Resource constraints

**Solution:**
```powershell
# Remove existing container
docker rm -f minio

# Remove volume if corrupted
docker volume rm minio_data

# Start fresh
.\run-docker-minio.ps1
```

## Security

### Change Default Credentials

**Critical for production!** Default credentials are public knowledge.

```powershell
# Edit docker-compose.yml
# Change MINIO_ROOT_USER and MINIO_ROOT_PASSWORD
# Restart: docker compose down && docker compose up -d
```

### Create Additional Users

1. Access Console: http://localhost:9002
2. Navigate to: Identity → Users → Create User
3. Set username and password
4. Assign policies (e.g., readwrite, readonly)

### Use Strong Passwords

Requirements:
- Minimum 8 characters (12+ recommended)
- Mix of uppercase, lowercase, numbers, symbols
- Avoid common words or patterns

### Network Security

**For production:**
- Don't expose ports directly to the internet
- Use reverse proxy (nginx, Traefik) with HTTPS
- Implement firewall rules
- Consider VPN access only

**Restrict to localhost:**
```yaml
ports:
  - "127.0.0.1:9000:9000"    # Only accessible from local machine
  - "127.0.0.1:9002:9001"
```

### Enable HTTPS/TLS

1. Obtain SSL certificates (Let's Encrypt, self-signed, or commercial)
2. Create certificate directory:
   ```powershell
   mkdir C:\MinIO\certs\CAs
   ```
3. Place certificates:
   - `C:\MinIO\certs\public.crt`
   - `C:\MinIO\certs\private.key`
   - `C:\MinIO\certs\CAs\` (for trusted CAs)
4. Update docker-compose.yml:
   ```yaml
   volumes:
     - minio_data:/data
     - C:\MinIO\certs:/root/.minio/certs
   ```
5. Restart container

### Regular Backups

Implement automated backups:
- Schedule using Windows Task Scheduler
- Test restore procedures regularly
- Store backups offsite or on different disk

### Monitor Access

Review access logs:
```powershell
# View MinIO audit logs
docker logs minio | Select-String "audit"
```

### Update Regularly

```powershell
# Check for updates
docker compose pull

# Apply updates
docker compose up -d
```

Subscribe to security advisories:
- MinIO Security: https://min.io/security
- Docker Security: https://www.docker.com/products/docker-desktop/security

## Additional Resources

### Official Documentation
- MinIO Documentation: https://min.io/docs/minio/windows/index.html
- MinIO Docker Hub: https://hub.docker.com/r/minio/minio
- Docker Documentation: https://docs.docker.com/

### Tools & Clients
- MinIO Client (mc): https://min.io/docs/minio/windows/reference/minio-mc.html
- AWS CLI: https://aws.amazon.com/cli/
- S3 Browser: https://s3browser.com/

### Community & Support
- MinIO Slack: https://slack.min.io/
- MinIO GitHub: https://github.com/minio/minio
- Stack Overflow: Tag `minio`

### Learning Resources
- MinIO Quick Start: https://min.io/docs/minio/windows/index.html#quickstart
- S3 API Reference: https://docs.aws.amazon.com/s3/
- Docker Compose Guide: https://docs.docker.com/compose/

## Version Information

- **MinIO**: Latest stable (automatically updated)
- **Docker Compose**: V2 (included with Docker Desktop)
- **Scripts**: Version 1.0 (2024)

---

**Questions or Issues?**
- Check the Troubleshooting section above
- Review Docker Desktop logs
- Consult MinIO documentation
- Raise an issue in the project repository
