# MinIO Docker Deployment for Ubuntu 24.04

This directory contains scripts and configuration to deploy MinIO as a Docker container on Ubuntu 24.04 LTS.

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
- Follows Linux Filesystem Hierarchy Standard (deployment to /opt)

## Prerequisites

### Required Software

1. **Ubuntu 24.04 LTS** (or compatible Debian-based distribution)
   - Kernel version 5.15 or higher
   - 64-bit x86_64 or ARM64 architecture

2. **Docker Engine** (latest version)
   - Minimum Requirements:
     - 2GB RAM (4GB recommended)
     - 2 CPU cores (4 recommended)
     - 20GB free disk space
   - Installation options:
     - Docker CE (Community Edition) from official repository
     - docker.io package from Ubuntu repository

3. **Docker Compose**
   - V2 (plugin): docker-compose-plugin package (recommended)
   - V1 (standalone): docker-compose package (legacy)

4. **System Access**
   - Root/sudo privileges for installation and Docker access
   - Standard user account (recommended for daily use with docker group)

### System Requirements

**Minimum:**
- 2 vCPU
- 4GB RAM
- 20GB disk space

**Recommended:**
- 4+ vCPU
- 8GB+ RAM
- 50GB+ disk space (depending on data storage needs)
- SSD for better performance

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
- Container runs in server mode with web console enabled
- `restart: always` ensures MinIO starts automatically after system reboot

### `copy-minio.sh`
Bash script to copy deployment files from the current directory to `/opt/minio`.

**What it does:**
1. Validates root/sudo privileges (required for /opt access)
2. Validates source directory and required files exist
3. Creates destination directory `/opt/minio` with proper permissions
4. Copies docker-compose.yml and run-docker-minio.sh
5. Makes run script executable (chmod +x)
6. Provides next steps guidance

**Features:**
- Color-coded output for better readability
- Comprehensive error checking at each step
- Auto-detects script location (no hardcoded paths)
- Detailed error messages with troubleshooting hints

**Usage:**
```bash
chmod +x copy-minio.sh    # First time only
sudo ./copy-minio.sh
```

### `run-docker-minio.sh`
Bash script to validate environment and start MinIO container.

**What it does:**
1. Checks if `/opt/minio` directory exists
2. Validates `docker-compose.yml` is present
3. Verifies Docker Engine is installed
4. Checks if Docker daemon is running
5. Detects Docker Compose version (V1 standalone or V2 plugin)
6. Starts MinIO in detached mode (background)
7. Displays access URLs, credentials, and management commands

**Features:**
- Comprehensive environment validation
- Clear error messages with installation guidance
- Colored output for status messages
- Returns to original directory after execution
- Handles both Docker Compose V1 and V2 syntax

**Usage:**
```bash
sudo /opt/minio/run-docker-minio.sh
```

### `README.md`
This comprehensive documentation file.

## Installation

### Step 1: Install Docker Engine

#### Option A: Official Docker Repository (Recommended)

```bash
# Update package index
sudo apt update

# Install prerequisites
sudo apt install -y ca-certificates curl gnupg lsb-release

# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Set up the Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt index
sudo apt update

# Install Docker Engine, CLI, and Docker Compose plugin
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Verify installation
sudo docker --version
sudo docker compose version
```

#### Option B: Ubuntu Repository (Simpler, may be older version)

```bash
# Update package index
sudo apt update

# Install Docker and Docker Compose
sudo apt install -y docker.io docker-compose-plugin

# Verify installation
sudo docker --version
sudo docker compose version
```

### Step 2: Configure Docker (Optional but Recommended)

#### Enable Docker at boot
```bash
sudo systemctl enable docker
sudo systemctl start docker
```

#### Add your user to docker group (avoid using sudo for every command)
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group changes (or log out and back in)
newgrp docker

# Test without sudo
docker ps
```

**Note:** After adding yourself to the docker group, you may need to log out and back in for changes to take effect.

### Step 3: Clone or Access Repository

Ensure the repository files are accessible on your Ubuntu system. Transfer files if needed:

```bash
# Example: Copy from Windows to Ubuntu via SCP
scp -r /path/to/Setup/MinIO/linux user@ubuntu-host:/tmp/minio-setup

# Or clone the repository
git clone <repository-url>
cd Workshop--Data-Integration/Setup/MinIO/linux
```

### Step 4: Deploy MinIO

```bash
# Navigate to the Linux setup directory
cd /path/to/Workshop--Data-Integration/Setup/MinIO/linux

# Make scripts executable (first time only)
chmod +x copy-minio.sh run-docker-minio.sh

# Run the copy script to deploy files to /opt/minio
sudo ./copy-minio.sh

# Start MinIO
sudo /opt/minio/run-docker-minio.sh
```

**What happens during deployment:**
1. Files copied to `/opt/minio`
2. Docker pulls MinIO image (~200MB, first time only)
3. Docker creates volume `minio_data`
4. Container starts in background
5. MinIO becomes accessible at configured ports

### Step 5: Verify Deployment

```bash
# Check container status
sudo docker ps

# Should show:
# CONTAINER ID   IMAGE               STATUS         PORTS                    NAMES
# xxxxxxxxxxxx   minio/minio:latest  Up X seconds   0.0.0.0:9000->9000/tcp   minio

# Test API endpoint
curl http://localhost:9000/minio/health/live
# Should return: HTTP 200 OK

# Access web console
# Open browser to: http://localhost:9002
# Login: minioadmin / minioadmin
```

## Usage

### Accessing MinIO

**Web Console (Browser UI):**
- URL: http://localhost:9002
- Purpose: Creating buckets, uploading files, managing users, viewing metrics
- Features: File browser, access control, monitoring, configuration

**API Endpoint (S3-Compatible):**
- URL: http://localhost:9000
- Purpose: Programmatic access via SDKs, AWS CLI, or S3-compatible tools
- Protocol: S3-compatible REST API

**Default Credentials:**
- Username: `minioadmin`
- Password: `minioadmin`
- **⚠️ CRITICAL:** Change these immediately for production use!

### Using MinIO Console

1. **Login**
   - Navigate to http://localhost:9002
   - Enter default credentials

2. **Create a Bucket**
   - Click "Buckets" in left sidebar
   - Click "Create Bucket" button
   - Enter bucket name (lowercase, no spaces)
   - Click "Create"

3. **Upload Files**
   - Click on bucket name
   - Click "Upload" button
   - Select files or drag-and-drop
   - Files are now accessible via S3 API

4. **Manage Access**
   - Identity → Users: Create additional users
   - Identity → Policies: Configure access policies
   - Buckets → [bucket] → Access: Set bucket-level permissions

### Using AWS CLI with MinIO

MinIO is S3-compatible, so you can use the AWS CLI.

**Install AWS CLI:**
```bash
# Ubuntu method
sudo apt install awscli

# Or using pip
pip install awscli
```

**Configure AWS CLI for MinIO:**
```bash
# Create a profile for MinIO
aws configure --profile minio

# When prompted, enter:
# AWS Access Key ID: minioadmin
# AWS Secret Access Key: minioadmin
# Default region name: us-east-1
# Default output format: json
```

**Common Operations:**
```bash
# Create a bucket
aws --profile minio --endpoint-url http://localhost:9000 s3 mb s3://my-bucket

# List buckets
aws --profile minio --endpoint-url http://localhost:9000 s3 ls

# Upload a file
aws --profile minio --endpoint-url http://localhost:9000 s3 cp file.txt s3://my-bucket/

# Download a file
aws --profile minio --endpoint-url http://localhost:9000 s3 cp s3://my-bucket/file.txt .

# List objects in bucket
aws --profile minio --endpoint-url http://localhost:9000 s3 ls s3://my-bucket/

# Delete a file
aws --profile minio --endpoint-url http://localhost:9000 s3 rm s3://my-bucket/file.txt

# Sync directory to bucket
aws --profile minio --endpoint-url http://localhost:9000 s3 sync ./local-dir s3://my-bucket/
```

### Using MinIO Client (mc)

MinIO provides its own CLI tool with more features than AWS CLI.

**Install MinIO Client:**
```bash
# Download
wget https://dl.min.io/client/mc/release/linux-amd64/mc

# Make executable
chmod +x mc

# Move to PATH
sudo mv mc /usr/local/bin/

# Verify
mc --version
```

**Configure MinIO Client:**
```bash
# Add alias for local MinIO
mc alias set local http://localhost:9000 minioadmin minioadmin

# Test connection
mc admin info local
```

**Common Operations:**
```bash
# List buckets
mc ls local

# Create bucket
mc mb local/my-bucket

# Upload file
mc cp file.txt local/my-bucket/

# Download file
mc cp local/my-bucket/file.txt .

# Mirror directory (sync)
mc mirror ./local-dir local/my-bucket/

# Watch for changes
mc watch local/my-bucket

# Create access key
mc admin user add local newuser newpassword

# Set policy
mc admin policy attach local readwrite --user newuser
```

## Configuration

### Changing Default Credentials

**CRITICAL:** Change credentials before production use!

1. **Stop MinIO:**
   ```bash
   cd /opt/minio
   sudo docker compose down
   ```

2. **Edit docker-compose.yml:**
   ```bash
   sudo nano /opt/minio/docker-compose.yml
   ```

3. **Update environment variables:**
   ```yaml
   environment:
     MINIO_ROOT_USER: your_secure_username
     MINIO_ROOT_PASSWORD: your_secure_password_min_8_chars
   ```

   **Requirements:**
   - Username: 5-20 characters, alphanumeric
   - Password: minimum 8 characters (12+ recommended)

4. **Save and restart:**
   ```bash
   sudo docker compose up -d
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
   ```bash
   cd /opt/minio
   sudo docker compose down
   sudo docker compose up -d
   ```

### Enable TLS/HTTPS

For production deployments, enable HTTPS:

1. **Generate or obtain SSL certificates:**
   ```bash
   # Self-signed certificate (for testing)
   sudo mkdir -p /opt/minio/certs
   sudo openssl req -new -x509 -days 365 -nodes \
     -out /opt/minio/certs/public.crt \
     -keyout /opt/minio/certs/private.key \
     -subj "/CN=localhost"
   ```

2. **Update docker-compose.yml:**
   ```yaml
   volumes:
     - minio_data:/data
     - /opt/minio/certs:/root/.minio/certs
   ```

3. **Set proper permissions:**
   ```bash
   sudo chmod 600 /opt/minio/certs/private.key
   sudo chmod 644 /opt/minio/certs/public.crt
   ```

4. **Restart container:**
   ```bash
   cd /opt/minio
   sudo docker compose down
   sudo docker compose up -d
   ```

5. **Access via HTTPS:**
   - Console: https://localhost:9002
   - API: https://localhost:9000

### Resource Limits

Limit container resource usage:

```yaml
services:
  minio:
    # ... existing config ...
    deploy:
      resources:
        limits:
          cpus: '2.0'       # Maximum 2 CPU cores
          memory: 4G        # Maximum 4GB RAM
        reservations:
          cpus: '1.0'       # Reserve 1 CPU core
          memory: 2G        # Reserve 2GB RAM
```

### Custom Data Directory

To use a specific host directory instead of Docker volume:

```yaml
volumes:
  - /path/to/data:/data  # Use host directory
  # Instead of: minio_data:/data
```

**Note:** Ensure proper permissions on host directory:
```bash
sudo mkdir -p /path/to/data
sudo chown -R 1000:1000 /path/to/data
```

## Management

All management commands should be run from `/opt/minio` or with full path.

### Check Container Status

```bash
# View running containers
sudo docker ps

# View all containers (including stopped)
sudo docker ps -a

# Using Docker Compose
cd /opt/minio
sudo docker compose ps

# Detailed status
sudo docker inspect minio
```

### View Logs

```bash
cd /opt/minio

# View all logs
sudo docker compose logs

# Follow logs in real-time (Ctrl+C to exit)
sudo docker compose logs -f

# View last 100 lines
sudo docker compose logs --tail=100

# View logs since 1 hour ago
sudo docker logs --since 1h minio

# View logs between timestamps
sudo docker logs --since "2024-01-20T10:00:00" --until "2024-01-20T11:00:00" minio
```

### Stop MinIO

```bash
cd /opt/minio

# Stop container (data is preserved)
sudo docker compose down

# Stop container only (don't remove)
sudo docker compose stop

# Stop with timeout
sudo docker compose stop -t 30
```

### Start MinIO

```bash
cd /opt/minio

# Start existing container
sudo docker compose start

# Or recreate and start
sudo docker compose up -d

# Or use the run script
sudo /opt/minio/run-docker-minio.sh
```

### Restart MinIO

```bash
cd /opt/minio

# Restart container
sudo docker compose restart

# Or stop and start
sudo docker compose down
sudo docker compose up -d

# Restart with timeout
sudo docker compose restart -t 30
```

### Update MinIO

```bash
cd /opt/minio

# Pull latest image
sudo docker compose pull

# Stop current container
sudo docker compose down

# Start with new image
sudo docker compose up -d

# Verify new version
sudo docker exec minio minio --version
```

### Remove Everything

```bash
cd /opt/minio

# Stop and remove container (data preserved in volume)
sudo docker compose down

# Remove container AND volume (⚠️ DELETES ALL DATA!)
sudo docker compose down -v

# Remove volume manually (if needed)
sudo docker volume rm minio_data

# Remove deployment directory (complete removal)
sudo rm -rf /opt/minio
```

### Auto-start at Boot

MinIO is configured with `restart: always` so it automatically starts at boot.

**Disable auto-start:**
```yaml
services:
  minio:
    restart: "no"  # or "unless-stopped"
```

**Check restart policy:**
```bash
sudo docker inspect minio | grep -A 3 "RestartPolicy"
```

## Data Persistence

### Understanding Docker Volumes

MinIO data is stored in a Docker-managed volume named `minio_data`:
- **Type:** Named volume (managed by Docker)
- **Location:** `/var/lib/docker/volumes/minio_data/_data` (typically)
- **Persistence:** Survives container restarts, updates, and removals
- **Isolation:** Protected from accidental deletion

### Inspect Volume

```bash
# View volume details
sudo docker volume inspect minio_data

# Output shows:
# - Mountpoint: Actual location on filesystem
# - Driver: Volume driver (usually "local")
# - Labels: Metadata

# Find exact location
sudo docker volume inspect minio_data | grep Mountpoint
```

### Access Volume Data Directly

```bash
# Get volume mountpoint
VOLUME_PATH=$(sudo docker volume inspect minio_data --format '{{ .Mountpoint }}')

# List contents
sudo ls -lah "$VOLUME_PATH"

# View MinIO internal structure
sudo tree -L 2 "$VOLUME_PATH"
```

**⚠️ Warning:** Direct filesystem access can corrupt MinIO data. Use only for inspection or when container is stopped.

### Backup Data

#### Method 1: Docker Volume Backup (Recommended)

```bash
# Create backup directory
mkdir -p ~/minio-backups

# Backup volume to tar.gz file
sudo docker run --rm \
  -v minio_data:/data:ro \
  -v ~/minio-backups:/backup \
  ubuntu \
  tar czf /backup/minio-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /data .

# List backups
ls -lh ~/minio-backups/
```

#### Method 2: Using MinIO Client (mc)

```bash
# Mirror all buckets to local directory
mc mirror local ~/minio-backups/buckets

# Sync specific bucket
mc mirror local/my-bucket ~/minio-backups/my-bucket
```

#### Method 3: AWS CLI Sync

```bash
# Sync all buckets
mkdir -p ~/minio-backups
for bucket in $(aws --profile minio --endpoint-url http://localhost:9000 s3 ls | awk '{print $3}'); do
  aws --profile minio --endpoint-url http://localhost:9000 s3 sync s3://$bucket ~/minio-backups/$bucket
done
```

### Restore Data

#### From Docker Volume Backup

```bash
# Stop MinIO
cd /opt/minio
sudo docker compose down

# Remove existing volume (⚠️ removes current data)
sudo docker volume rm minio_data

# Create new volume
sudo docker volume create minio_data

# Restore from backup
sudo docker run --rm \
  -v minio_data:/data \
  -v ~/minio-backups:/backup \
  ubuntu \
  tar xzf /backup/minio-backup-20240123-120000.tar.gz -C /data

# Start MinIO
sudo docker compose up -d
```

#### From MinIO Client Mirror

```bash
# Ensure MinIO is running
mc mirror ~/minio-backups/buckets local --overwrite
```

### Automated Backups

Create a cron job for automated backups:

```bash
# Edit crontab
crontab -e

# Add daily backup at 2 AM
0 2 * * * /usr/bin/docker run --rm -v minio_data:/data:ro -v /home/user/minio-backups:/backup ubuntu tar czf /backup/minio-backup-$(date +\%Y\%m\%d).tar.gz -C /data . && find /home/user/minio-backups -name "minio-backup-*.tar.gz" -mtime +30 -delete
```

This cron job:
1. Backs up MinIO data daily at 2 AM
2. Creates dated backup files
3. Deletes backups older than 30 days

## Troubleshooting

### Docker Not Running

**Symptoms:**
- Error: "Cannot connect to the Docker daemon"
- Error: "docker: command not found"

**Solution:**
```bash
# Check if Docker is installed
docker --version

# If not installed, see Installation section

# Check Docker service status
sudo systemctl status docker

# Start Docker service
sudo systemctl start docker

# Enable auto-start at boot
sudo systemctl enable docker

# Verify Docker is running
sudo docker ps
```

### Port Already in Use

**Symptoms:**
- Error: "port is already allocated"
- Error: "bind: address already in use"

**Solution:**
```bash
# Find process using port 9000
sudo netstat -tlnp | grep :9000
# Or
sudo lsof -i :9000

# Kill process (replace PID with actual process ID)
sudo kill -9 <PID>

# Or change ports in docker-compose.yml
```

### Container Fails to Start

**Check logs:**
```bash
cd /opt/minio
sudo docker compose logs

# Or
sudo docker logs minio --tail 50
```

**Common issues and solutions:**

1. **Insufficient disk space:**
   ```bash
   # Check disk space
   df -h /var/lib/docker

   # Clean up Docker resources
   sudo docker system prune -a
   ```

2. **Permission issues:**
   ```bash
   # Fix volume permissions
   sudo docker run --rm -v minio_data:/data ubuntu chown -R 1000:1000 /data
   ```

3. **Corrupted volume:**
   ```bash
   # Remove and recreate volume
   sudo docker compose down
   sudo docker volume rm minio_data
   sudo docker compose up -d
   ```

4. **Memory limits:**
   ```bash
   # Check available memory
   free -h

   # Check Docker memory usage
   sudo docker stats minio --no-stream
   ```

### Cannot Access Web Console

**Check container is running:**
```bash
sudo docker ps | grep minio
```

**Check if ports are accessible:**
```bash
# Test API port
curl http://localhost:9000/minio/health/live

# Test Console port
curl http://localhost:9002

# If using firewall, allow ports
sudo ufw allow 9000/tcp
sudo ufw allow 9002/tcp
sudo ufw reload
```

**Check from remote machine:**
```bash
# On remote machine
curl http://<ubuntu-ip>:9002

# If fails, check firewall and ensure ports are bound to 0.0.0.0, not 127.0.0.1
```

### Permission Denied Errors

**If running commands without sudo fails:**

```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply changes (or log out and back in)
newgrp docker

# Test without sudo
docker ps
```

**If volume permission errors occur:**
```bash
# Fix volume ownership
sudo docker run --rm -v minio_data:/data ubuntu chown -R 1000:1000 /data

# Restart container
cd /opt/minio
sudo docker compose restart
```

### Container Keeps Restarting

**Check restart policy:**
```bash
sudo docker inspect minio | grep -A 3 "RestartPolicy"
```

**View recent logs:**
```bash
sudo docker logs minio --tail 100 --follow
```

**Common causes:**
- Invalid configuration in docker-compose.yml
- Port conflicts
- Resource constraints (memory/CPU)
- Corrupted data volume

**Solution:**
```bash
# Remove container and start fresh
sudo docker rm -f minio

# Check configuration
sudo nano /opt/minio/docker-compose.yml

# Start again
cd /opt/minio
sudo docker compose up -d
```

### Slow Performance

**Check resource usage:**
```bash
# Container resource usage
sudo docker stats minio

# System resources
htop  # or top

# Disk I/O
sudo iotop
```

**Improve performance:**

1. **Increase container resources** (edit docker-compose.yml):
   ```yaml
   deploy:
     resources:
       limits:
         cpus: '4'
         memory: 8G
   ```

2. **Use SSD for Docker storage:**
   ```bash
   # Move Docker data directory to SSD
   sudo systemctl stop docker
   sudo mv /var/lib/docker /ssd/docker
   sudo ln -s /ssd/docker /var/lib/docker
   sudo systemctl start docker
   ```

3. **Clean up unused resources:**
   ```bash
   sudo docker system prune -a
   sudo docker volume prune
   ```

### Network Issues

**Container cannot reach internet:**
```bash
# Check Docker network
sudo docker network inspect bridge

# Test from container
sudo docker exec minio ping -c 3 8.8.8.8

# Check DNS
sudo docker exec minio cat /etc/resolv.conf
```

**Cannot access container from host:**
```bash
# Check port bindings
sudo docker port minio

# Check firewall rules
sudo ufw status

# Check iptables
sudo iptables -L -n | grep 9000
```

## Security

### Change Default Credentials

**CRITICAL:** Default credentials are publicly known. Change immediately!

```bash
# Stop container
cd /opt/minio
sudo docker compose down

# Edit configuration
sudo nano docker-compose.yml

# Change credentials:
# MINIO_ROOT_USER: your_secure_username
# MINIO_ROOT_PASSWORD: your_very_secure_password_with_symbols123!

# Restart
sudo docker compose up -d
```

### Strong Password Requirements

- Minimum 12 characters (20+ for production)
- Mix of uppercase, lowercase, numbers, symbols
- Avoid dictionary words
- Use a password manager

**Generate strong password:**
```bash
# Random 20-character password
openssl rand -base64 20

# Or using pwgen
pwgen -s 20 1
```

### Create Additional Users

Don't use root user for applications. Create service accounts:

1. **Via Console:**
   - Access http://localhost:9002
   - Identity → Users → Create User
   - Set username and password
   - Assign policies (readwrite, readonly, etc.)

2. **Via MinIO Client:**
   ```bash
   # Create user
   mc admin user add local newuser securepassword

   # Attach policy
   mc admin policy attach local readwrite --user newuser

   # List users
   mc admin user list local
   ```

### Access Policies

Create custom policies for fine-grained access control:

```bash
# Create policy file
cat > /tmp/readonly-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:ListBucket"],
      "Resource": ["arn:aws:s3:::*"]
    }
  ]
}
EOF

# Add policy
mc admin policy create local readonly-custom /tmp/readonly-policy.json

# Attach to user
mc admin policy attach local readonly-custom --user someuser
```

### Network Security

**For production deployments:**

1. **Use firewall to restrict access:**
   ```bash
   # Allow only from specific IP
   sudo ufw allow from 192.168.1.0/24 to any port 9000
   sudo ufw allow from 192.168.1.0/24 to any port 9002
   ```

2. **Bind to specific interface** (edit docker-compose.yml):
   ```yaml
   ports:
     - "127.0.0.1:9000:9000"  # Only localhost
     - "127.0.0.1:9002:9001"
   ```

3. **Use reverse proxy** (nginx, Traefik) with HTTPS:
   ```nginx
   server {
     listen 443 ssl;
     server_name minio.example.com;

     ssl_certificate /path/to/cert.pem;
     ssl_certificate_key /path/to/key.pem;

     location / {
       proxy_pass http://localhost:9002;
       proxy_set_header Host $host;
     }
   }
   ```

4. **Enable TLS/HTTPS** (see Configuration section)

5. **Use VPN for remote access**

### Enable Audit Logging

Track all access to MinIO:

```bash
# Enable audit webhook (example: send to syslog)
mc admin config set local audit_webhook \
  endpoint="http://syslog-server:514" \
  auth_token="your-token"

# Or enable file-based audit logging
# Add to docker-compose.yml:
environment:
  MINIO_AUDIT_WEBHOOK_ENABLE_target1: "on"
  MINIO_AUDIT_WEBHOOK_ENDPOINT_target1: "http://logs:514"
```

### Regular Backups

Implement automated, tested backup procedures (see Data Persistence section).

### Keep Software Updated

```bash
# Check current version
sudo docker exec minio minio --version

# Check for updates
sudo docker compose pull

# Apply updates
cd /opt/minio
sudo docker compose down
sudo docker compose up -d

# Verify
sudo docker exec minio minio --version
```

### Security Best Practices

1. **Credentials:**
   - Change default credentials immediately
   - Use strong, unique passwords
   - Rotate credentials regularly
   - Never commit credentials to version control

2. **Network:**
   - Enable TLS/HTTPS for production
   - Use firewall to restrict access
   - Consider VPN for remote access
   - Use reverse proxy with rate limiting

3. **Access Control:**
   - Follow principle of least privilege
   - Create specific users for applications
   - Use IAM policies for fine-grained control
   - Regularly audit user access

4. **Monitoring:**
   - Enable audit logging
   - Monitor access logs regularly
   - Set up alerts for suspicious activity
   - Track resource usage

5. **Updates:**
   - Keep MinIO updated
   - Keep Docker updated
   - Subscribe to security advisories
   - Test updates in non-production first

6. **Backups:**
   - Implement automated backups
   - Store backups offsite
   - Test restore procedures regularly
   - Encrypt backup files

## Additional Resources

### Official Documentation
- MinIO Documentation: https://min.io/docs/minio/linux/index.html
- MinIO Docker Hub: https://hub.docker.com/r/minio/minio
- Docker Documentation: https://docs.docker.com/
- Docker Compose: https://docs.docker.com/compose/

### Tools & Clients
- MinIO Client (mc): https://min.io/docs/minio/linux/reference/minio-mc.html
- AWS CLI: https://aws.amazon.com/cli/
- S3 Browser: https://cyberduck.io/ (cross-platform)
- MinIO Console: Built-in web interface

### SDKs & Integration
- Python: https://min.io/docs/minio/linux/developers/python/minio-py.html
- Java: https://min.io/docs/minio/linux/developers/java/minio-java.html
- JavaScript: https://min.io/docs/minio/linux/developers/javascript/minio-javascript.html
- Go: https://min.io/docs/minio/linux/developers/go/minio-go.html

### Community & Support
- MinIO Slack: https://slack.min.io/
- MinIO GitHub: https://github.com/minio/minio
- Stack Overflow: Tag `minio`
- Community Forum: https://discuss.min.io/

### Learning Resources
- MinIO Quick Start: https://min.io/docs/minio/linux/index.html#quickstart
- S3 API Reference: https://docs.aws.amazon.com/s3/
- Docker Compose Guide: https://docs.docker.com/compose/gettingstarted/
- Best Practices: https://min.io/docs/minio/linux/operations/deployment-best-practices.html

### Security Resources
- MinIO Security: https://min.io/security
- CVE Database: https://cve.mitre.org/ (search "MinIO")
- Docker Security: https://docs.docker.com/engine/security/
- OWASP Guidelines: https://owasp.org/

## Version Information

- **MinIO**: Latest stable (automatically updated via Docker)
- **Docker Compose**: V2 recommended (included in docker-compose-plugin)
- **Scripts**: Version 1.0 (2024)
- **Documentation**: Last updated 2024-01-23

## Support

**For issues with this deployment:**
- Check the Troubleshooting section
- Review Docker and MinIO logs
- Verify system requirements are met

**For MinIO-specific issues:**
- MinIO Documentation: https://min.io/docs/
- Community Slack: https://slack.min.io/
- GitHub Issues: https://github.com/minio/minio/issues

**For Docker issues:**
- Docker Documentation: https://docs.docker.com/
- Docker Forums: https://forums.docker.com/
- Ubuntu Docker Guide: https://docs.docker.com/engine/install/ubuntu/

---

**Ready to deploy?**

```bash
chmod +x copy-minio.sh run-docker-minio.sh
sudo ./copy-minio.sh
sudo /opt/minio/run-docker-minio.sh
```

Then access the console at http://localhost:9002 and start using MinIO!
