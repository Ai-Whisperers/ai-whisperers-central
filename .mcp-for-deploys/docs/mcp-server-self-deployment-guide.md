# MCP Server Self-Deployment Guide

A comprehensive guide for deploying your MCP Deployment Server with Docker, WSL2, and secure tunneling solutions.

## Table of Contents
- [Self-Deployment Overview](#self-deployment-overview)
- [Docker Deployment Strategies](#docker-deployment-strategies)
- [Platform-Specific Setup](#platform-specific-setup)
- [Tunneling Solutions](#tunneling-solutions)
- [Complete Deployment Automation](#complete-deployment-automation)
- [Production Considerations](#production-considerations)

---

## Self-Deployment Overview

Your MCP server needs to be deployed and accessible for Claude to use it. This guide covers:

1. **Dockerization** - Packaging your MCP server as a container
2. **Platform Setup** - WSL2 for Windows, native Docker for Linux
3. **Tunneling** - Exposing your local server securely (Cloudflare, ngrok, Tailscale)
4. **Automation** - One-command deployment scripts

---

## Docker Deployment Strategies

### Why Avoid Docker Desktop?

**When to Avoid Docker Desktop:**

1. **Resource Consumption**: Docker Desktop uses significant RAM and CPU
2. **Licensing**: Commercial use requires a paid license for larger organizations
3. **WSL2 Overhead**: Adds an extra abstraction layer on Windows
4. **Linux**: Not needed - native Docker is lighter and faster

**Alternatives:**

- **Windows**: Docker in WSL2 (native Docker engine without Desktop)
- **Linux**: Native Docker Engine
- **Remote**: Deploy to cloud and tunnel back

### Architecture Comparison

```
┌─────────────────────────────────────────────────────────────┐
│                      WINDOWS OPTIONS                         │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Option 1: Docker Desktop (❌ Avoid if possible)            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Windows Host                                         │  │
│  │    ├─ Docker Desktop                                  │  │
│  │    │   ├─ WSL2 VM (managed by Desktop)               │  │
│  │    │   │   └─ Docker Engine                           │  │
│  │    │   └─ GUI + Additional Services (overhead)        │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
│  Option 2: WSL2 + Native Docker (✅ Recommended)            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Windows Host                                         │  │
│  │    ├─ WSL2 (Ubuntu)                                   │  │
│  │    │   └─ Docker Engine (native)                      │  │
│  │    └─ Direct socket access from Windows               │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      LINUX OPTIONS                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  Option 1: Native Docker Engine (✅ Recommended)            │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Linux Host                                           │  │
│  │    └─ Docker Engine (native)                          │  │
│  │       └─ Systemd service                              │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## Platform-Specific Setup

### Windows Setup (WSL2 + Native Docker)

#### Step 1: Install WSL2

```powershell
# PowerShell (Administrator)
# Enable WSL
wsl --install

# Install Ubuntu (or your preferred distro)
wsl --install -d Ubuntu-22.04

# Set WSL2 as default
wsl --set-default-version 2

# Verify installation
wsl --list --verbose
```

#### Step 2: Install Docker in WSL2

```bash
# Inside WSL2 Ubuntu terminal
# Update packages
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to docker group (avoid sudo)
sudo usermod -aG docker $USER

# Enable Docker to start on boot
sudo systemctl enable docker
sudo systemctl start docker

# Verify installation
docker --version
docker compose version
```

#### Step 3: Configure Docker Socket Access from Windows

```bash
# In WSL2
# Ensure Docker socket has correct permissions
sudo chmod 666 /var/run/docker.sock

# Make this persistent (add to ~/.bashrc or create systemd service)
echo 'sudo chmod 666 /var/run/docker.sock' >> ~/.bashrc
```

**Better approach - Create a systemd service:**

```bash
# Create service file
sudo nano /etc/systemd/system/docker-sock-permissions.service
```

```ini
[Unit]
Description=Set Docker socket permissions
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
ExecStart=/bin/chmod 666 /var/run/docker.sock
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
```

```bash
# Enable the service
sudo systemctl enable docker-sock-permissions.service
sudo systemctl start docker-sock-permissions.service
```

#### Step 4: Access Docker from Windows

```powershell
# In PowerShell, you can access WSL2 Docker via:
wsl docker ps

# Or set DOCKER_HOST environment variable
$env:DOCKER_HOST = "unix:///mnt/wsl/docker-desktop/docker.sock"

# Or for permanent access:
[System.Environment]::SetEnvironmentVariable('DOCKER_HOST', 'unix:///mnt/wsl/docker-desktop/docker.sock', 'User')
```

### Linux Setup (Native Docker)

#### Ubuntu/Debian

```bash
# Update packages
sudo apt update
sudo apt upgrade -y

# Install dependencies
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker
sudo systemctl enable docker
sudo systemctl start docker

# Apply group changes (or logout/login)
newgrp docker

# Verify
docker --version
docker compose version
```

#### Fedora/RHEL/CentOS

```bash
# Install Docker
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# Verify
docker --version
```

---

## Dockerizing Your MCP Server

### Project Structure

```
mcp-deployment-server/
├── Dockerfile
├── docker-compose.yml
├── .dockerignore
├── requirements.txt (Python) or package.json (Node)
├── src/
│   ├── server.py or index.ts
│   └── ...
├── deploy.sh (Linux/WSL2)
├── deploy.ps1 (Windows)
└── README.md
```

### Dockerfile (Python Version)

```dockerfile
# Dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy requirements
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Create non-root user
RUN useradd -m -u 1000 mcpuser && \
    chown -R mcpuser:mcpuser /app

USER mcpuser

# Expose port (if using HTTP transport)
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV MCP_TRANSPORT=stdio

# Run the server
CMD ["python", "src/server.py"]
```

### Dockerfile (Node.js/TypeScript Version)

```dockerfile
# Dockerfile
FROM node:18-alpine

# Install system dependencies
RUN apk add --no-cache \
    curl \
    git \
    docker-cli \
    bash

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source code
COPY src/ ./src/

# Build TypeScript
RUN npm run build

# Create non-root user
RUN addgroup -g 1000 mcpuser && \
    adduser -D -u 1000 -G mcpuser mcpuser && \
    chown -R mcpuser:mcpuser /app

USER mcpuser

# Expose port
EXPOSE 8080

# Run the server
CMD ["node", "dist/index.js"]
```

### .dockerignore

```
# .dockerignore
node_modules
npm-debug.log
.git
.gitignore
.env
.env.local
*.md
.vscode
.idea
__pycache__
*.pyc
.pytest_cache
dist
build
.DS_Store
```

### Docker Compose Configuration

```yaml
# docker-compose.yml
version: '3.8'

services:
  mcp-server:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: mcp-deployment-server
    
    # Port mapping (for HTTP transport)
    ports:
      - "8080:8080"
    
    # Volume mounts
    volumes:
      # Docker socket access (for deploying containers)
      - /var/run/docker.sock:/var/run/docker.sock
      
      # Kubernetes config (optional)
      - ${HOME}/.kube:/home/mcpuser/.kube:ro
      
      # Project directory access (optional, for local development)
      - ${MCP_WORKSPACE_DIR:-./workspace}:/workspace:ro
    
    # Environment variables
    environment:
      - MCP_TRANSPORT=${MCP_TRANSPORT:-stdio}
      - MCP_PORT=${MCP_PORT:-8080}
      - MCP_READ_ONLY=${MCP_READ_ONLY:-false}
      - DOCKER_HOST=unix:///var/run/docker.sock
      
      # Cloudflare tunnel token (if using)
      - CLOUDFLARE_TUNNEL_TOKEN=${CLOUDFLARE_TUNNEL_TOKEN}
      
      # Logging
      - LOG_LEVEL=${LOG_LEVEL:-info}
    
    # Restart policy
    restart: unless-stopped
    
    # Health check
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    
    # Resource limits
    deploy:
      resources:
        limits:
          cpus: '1'
          memory: 512M
        reservations:
          cpus: '0.25'
          memory: 256M
    
    # Networks
    networks:
      - mcp-network

networks:
  mcp-network:
    driver: bridge
```

### Environment Configuration

```bash
# .env.example
# Copy this to .env and fill in your values

# MCP Configuration
MCP_TRANSPORT=http
MCP_PORT=8080
MCP_READ_ONLY=false

# Workspace
MCP_WORKSPACE_DIR=/home/username/projects

# Cloudflare Tunnel (if using)
CLOUDFLARE_TUNNEL_TOKEN=your_tunnel_token_here

# Logging
LOG_LEVEL=info

# Platform Credentials (encrypt these in production!)
DOCKER_REGISTRY_USER=
DOCKER_REGISTRY_TOKEN=
K8S_CLUSTER_URL=
VERCEL_TOKEN=
RAILWAY_TOKEN=
```

---

## Tunneling Solutions

### Why Use Tunnels?

Tunnels allow your local MCP server to be accessible:
- From Claude Desktop running on a different machine
- For remote team members
- For production deployments without complex networking
- With HTTPS and authentication built-in

### Comparison of Tunnel Solutions

| Feature | Cloudflare Tunnel | ngrok | Tailscale |
|---------|------------------|-------|-----------|
| **Cost** | Free for personal | Free tier + paid | Free for personal |
| **Speed** | Fast (CDN) | Fast | Very fast (P2P) |
| **HTTPS** | Automatic | Automatic | Manual setup |
| **Auth** | Cloudflare Access | Basic auth | Built-in |
| **Setup** | Medium | Easy | Medium |
| **Use Case** | Production | Development | Private network |

---

## Cloudflare Tunnel Setup

### Why Cloudflare Tunnel?

✅ Free for personal use  
✅ Built-in DDoS protection  
✅ No exposed ports  
✅ Cloudflare's global CDN  
✅ Access control with Cloudflare Access  
✅ No bandwidth limits  

### Architecture

```
┌──────────────┐    HTTPS    ┌─────────────┐    Tunnel    ┌──────────────┐
│              │────────────>│  Cloudflare │<─────────────│  Your Local  │
│  Claude AI   │             │     CDN     │              │  MCP Server  │
│              │<────────────│   Network   │─────────────>│   :8080      │
└──────────────┘             └─────────────┘              └──────────────┘
```

### Installation and Setup

#### Step 1: Install cloudflared

**Windows (PowerShell as Administrator):**

```powershell
# Download cloudflared
Invoke-WebRequest -Uri "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe" -OutFile "$env:USERPROFILE\cloudflared.exe"

# Add to PATH
$oldPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = "$oldPath;$env:USERPROFILE"
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

# Verify installation
cloudflared --version
```

**Windows (WSL2):**

```bash
# In WSL2 terminal
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb
cloudflared --version
```

**Linux:**

```bash
# Ubuntu/Debian
curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared.deb

# Fedora/RHEL
sudo rpm -i https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-x86_64.rpm

# Verify
cloudflared --version
```

#### Step 2: Authenticate with Cloudflare

```bash
# This will open a browser for authentication
cloudflared tunnel login
```

This creates a cert.pem file at:
- **Windows**: `C:\Users\<username>\.cloudflared\cert.pem`
- **Linux**: `~/.cloudflared/cert.pem`

#### Step 3: Create a Tunnel

```bash
# Create tunnel
cloudflared tunnel create mcp-deployment-server

# This generates:
# - Tunnel ID (save this!)
# - Credentials file: ~/.cloudflared/<tunnel-id>.json
```

**Save the tunnel ID and credentials path!**

#### Step 4: Configure DNS

```bash
# Route your domain to the tunnel
cloudflared tunnel route dns mcp-deployment-server mcp.yourdomain.com

# Or use a Cloudflare subdomain (if you don't have a domain)
# Cloudflare will provide a trycloudflare.com URL
```

#### Step 5: Create Configuration File

**Windows (PowerShell):**

```powershell
# Create config directory
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.cloudflared"

# Create config file
@"
tunnel: <your-tunnel-id>
credentials-file: C:\Users\<username>\.cloudflared\<tunnel-id>.json

ingress:
  - hostname: mcp.yourdomain.com
    service: http://localhost:8080
  - service: http_status:404
"@ | Out-File -FilePath "$env:USERPROFILE\.cloudflared\config.yml" -Encoding UTF8
```

**Linux/WSL2:**

```bash
# Create config directory
mkdir -p ~/.cloudflared

# Create config file
cat > ~/.cloudflared/config.yml <<EOF
tunnel: <your-tunnel-id>
credentials-file: /home/<username>/.cloudflared/<tunnel-id>.json

ingress:
  - hostname: mcp.yourdomain.com
    service: http://localhost:8080
  - service: http_status:404
EOF
```

#### Step 6: Environment Variables Configuration

**Windows (PowerShell - Persistent):**

```powershell
# Set environment variables
[Environment]::SetEnvironmentVariable('CLOUDFLARE_TUNNEL_ID', '<your-tunnel-id>', 'User')
[Environment]::SetEnvironmentVariable('CLOUDFLARE_TUNNEL_TOKEN', '<your-tunnel-token>', 'User')

# Add cloudflared to PATH if not already done
$oldPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$newPath = "$oldPath;C:\Program Files\cloudflared"
[Environment]::SetEnvironmentVariable('Path', $newPath, 'User')

# Restart terminal or refresh environment
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","User")
```

**Linux/WSL2:**

```bash
# Add to ~/.bashrc or ~/.zshrc
echo 'export CLOUDFLARE_TUNNEL_ID="<your-tunnel-id>"' >> ~/.bashrc
echo 'export CLOUDFLARE_TUNNEL_TOKEN="<your-tunnel-token>"' >> ~/.bashrc

# Reload
source ~/.bashrc
```

#### Step 7: Run the Tunnel

**As a foreground process (testing):**

```bash
cloudflared tunnel run mcp-deployment-server
```

**As a background service (production):**

**Windows (NSSM - Non-Sucking Service Manager):**

```powershell
# Download NSSM
Invoke-WebRequest -Uri "https://nssm.cc/release/nssm-2.24.zip" -OutFile "$env:TEMP\nssm.zip"
Expand-Archive -Path "$env:TEMP\nssm.zip" -DestinationPath "$env:TEMP\nssm"

# Install service
& "$env:TEMP\nssm\nssm-2.24\win64\nssm.exe" install cloudflared-mcp "$env:USERPROFILE\cloudflared.exe"
& "$env:TEMP\nssm\nssm-2.24\win64\nssm.exe" set cloudflared-mcp AppParameters "tunnel run mcp-deployment-server"
& "$env:TEMP\nssm\nssm-2.24\win64\nssm.exe" set cloudflared-mcp AppDirectory "$env:USERPROFILE\.cloudflared"

# Start service
& "$env:TEMP\nssm\nssm-2.24\win64\nssm.exe" start cloudflared-mcp
```

**Linux (systemd):**

```bash
# Install as service
sudo cloudflared service install

# Start service
sudo systemctl start cloudflared
sudo systemctl enable cloudflared

# Check status
sudo systemctl status cloudflared
```

**WSL2 (using supervisor):**

```bash
# Install supervisor
sudo apt install supervisor

# Create supervisor config
sudo nano /etc/supervisor/conf.d/cloudflared.conf
```

```ini
[program:cloudflared]
command=/usr/local/bin/cloudflared tunnel run mcp-deployment-server
directory=/home/<username>/.cloudflared
user=<username>
autostart=true
autorestart=true
stderr_logfile=/var/log/cloudflared.err.log
stdout_logfile=/var/log/cloudflared.out.log
```

```bash
# Reload and start
sudo supervisorctl reread
sudo supervisorctl update
sudo supervisorctl start cloudflared
```

### Testing the Tunnel

```bash
# Check tunnel status
cloudflared tunnel info mcp-deployment-server

# Test connection
curl https://mcp.yourdomain.com/health
```

---

## ngrok Setup (Simpler Alternative)

### Installation

**Windows:**

```powershell
# Using Chocolatey
choco install ngrok

# Or download manually
Invoke-WebRequest -Uri "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-windows-amd64.zip" -OutFile "$env:TEMP\ngrok.zip"
Expand-Archive -Path "$env:TEMP\ngrok.zip" -DestinationPath "$env:USERPROFILE\ngrok"
```

**Linux:**

```bash
# Download and install
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update
sudo apt install ngrok
```

### Configuration

```bash
# Authenticate (get token from ngrok.com)
ngrok config add-authtoken <your-auth-token>

# Start tunnel
ngrok http 8080

# With custom subdomain (paid plan)
ngrok http --domain=mcp.yourdomain.com 8080
```

### Running as Service

**Linux (systemd):**

```bash
# Create service file
sudo nano /etc/systemd/system/ngrok.service
```

```ini
[Unit]
Description=ngrok tunnel
After=network.target

[Service]
Type=simple
User=<username>
ExecStart=/usr/local/bin/ngrok http --log stdout 8080
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

```bash
# Enable and start
sudo systemctl enable ngrok
sudo systemctl start ngrok
```

---

## Tailscale Setup (Private Network)

### When to Use Tailscale?

- For private team networks
- When you need peer-to-peer connections
- For development/staging environments
- When you want zero-trust security

### Installation

**Windows:**

Download from [tailscale.com/download/windows](https://tailscale.com/download/windows)

**Linux:**

```bash
# Ubuntu/Debian
curl -fsSL https://tailscale.com/install.sh | sh

# Start Tailscale
sudo tailscale up

# Get IP
tailscale ip -4
```

### Configuration

```bash
# Enable subnet routing (optional)
sudo tailscale up --advertise-routes=192.168.0.0/24

# Share node (for team access)
tailscale share <node-name>
```

### Access Your MCP Server

```bash
# From any device on your Tailscale network
curl http://<tailscale-ip>:8080
```

---

## Complete Deployment Automation

### Deployment Script (Linux/WSL2)

```bash
#!/bin/bash
# deploy.sh

set -e

echo "🚀 MCP Deployment Server - Automated Deployment"
echo "================================================"

# Configuration
PROJECT_NAME="mcp-deployment-server"
DOCKER_IMAGE="$PROJECT_NAME:latest"
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"

# Detect platform
if grep -qi microsoft /proc/version; then
    PLATFORM="WSL2"
    echo "📍 Platform: WSL2"
elif [ -f /etc/os-release ]; then
    PLATFORM="Linux"
    echo "📍 Platform: Linux"
else
    echo "❌ Unsupported platform"
    exit 1
fi

# Check dependencies
echo ""
echo "🔍 Checking dependencies..."

check_command() {
    if ! command -v $1 &> /dev/null; then
        echo "❌ $1 is not installed"
        return 1
    else
        echo "✅ $1 is installed"
        return 0
    fi
}

check_command docker || {
    echo "Please install Docker first"
    exit 1
}

check_command docker compose || {
    echo "Please install Docker Compose plugin"
    exit 1
}

# Load environment variables
if [ -f "$ENV_FILE" ]; then
    echo "📄 Loading environment from $ENV_FILE"
    export $(cat $ENV_FILE | grep -v '^#' | xargs)
else
    echo "⚠️  No .env file found, using defaults"
fi

# Choose tunnel solution
echo ""
echo "🌐 Choose tunnel solution:"
echo "1) Cloudflare Tunnel (recommended for production)"
echo "2) ngrok (quick setup)"
echo "3) Tailscale (private network)"
echo "4) None (local only)"
read -p "Enter choice [1-4]: " tunnel_choice

case $tunnel_choice in
    1)
        TUNNEL="cloudflare"
        if ! check_command cloudflared; then
            echo "Installing cloudflared..."
            curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
            sudo dpkg -i cloudflared.deb
            rm cloudflared.deb
        fi
        ;;
    2)
        TUNNEL="ngrok"
        if ! check_command ngrok; then
            echo "Installing ngrok..."
            curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
            echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
            sudo apt update && sudo apt install ngrok
        fi
        ;;
    3)
        TUNNEL="tailscale"
        if ! check_command tailscale; then
            echo "Installing Tailscale..."
            curl -fsSL https://tailscale.com/install.sh | sh
        fi
        ;;
    4)
        TUNNEL="none"
        ;;
esac

# Build Docker image
echo ""
echo "🏗️  Building Docker image..."
docker compose build

# Stop existing container
echo ""
echo "🛑 Stopping existing containers..."
docker compose down

# Start container
echo ""
echo "🚀 Starting MCP server..."
docker compose up -d

# Wait for container to be ready
echo ""
echo "⏳ Waiting for server to be ready..."
sleep 5

# Health check
echo ""
echo "🏥 Health check..."
if curl -f http://localhost:8080/health &> /dev/null; then
    echo "✅ Server is healthy"
else
    echo "⚠️  Server may not be ready yet"
fi

# Setup tunnel
echo ""
if [ "$TUNNEL" = "cloudflare" ]; then
    echo "🌐 Starting Cloudflare Tunnel..."
    
    if [ -z "$CLOUDFLARE_TUNNEL_ID" ]; then
        echo "⚠️  CLOUDFLARE_TUNNEL_ID not set"
        echo "Run: cloudflared tunnel create mcp-deployment-server"
        echo "Then add the tunnel ID to .env"
    else
        # Start tunnel in background
        nohup cloudflared tunnel run $CLOUDFLARE_TUNNEL_ID > /tmp/cloudflared.log 2>&1 &
        echo "✅ Cloudflare tunnel started"
        echo "📋 URL: https://mcp.yourdomain.com"
    fi
    
elif [ "$TUNNEL" = "ngrok" ]; then
    echo "🌐 Starting ngrok tunnel..."
    
    if [ -z "$NGROK_AUTH_TOKEN" ]; then
        echo "⚠️  NGROK_AUTH_TOKEN not set"
        echo "Get token from: https://dashboard.ngrok.com/get-started/your-authtoken"
        echo "Run: ngrok config add-authtoken <token>"
    else
        ngrok config add-authtoken $NGROK_AUTH_TOKEN
        nohup ngrok http 8080 > /tmp/ngrok.log 2>&1 &
        sleep 2
        NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"[^"]*' | grep -o 'https://[^"]*')
        echo "✅ ngrok tunnel started"
        echo "📋 URL: $NGROK_URL"
    fi
    
elif [ "$TUNNEL" = "tailscale" ]; then
    echo "🌐 Configuring Tailscale..."
    
    sudo tailscale up
    TAILSCALE_IP=$(tailscale ip -4)
    echo "✅ Tailscale configured"
    echo "📋 URL: http://$TAILSCALE_IP:8080"
    
else
    echo "📋 Server running locally at: http://localhost:8080"
fi

# Show logs
echo ""
echo "📊 Container status:"
docker compose ps

echo ""
echo "📝 View logs with: docker compose logs -f"
echo "🛑 Stop server with: docker compose down"
echo ""
echo "✨ Deployment complete!"
```

### Deployment Script (Windows PowerShell)

```powershell
# deploy.ps1

param(
    [Parameter(Mandatory=$false)]
    [string]$Tunnel = "prompt"
)

Write-Host "🚀 MCP Deployment Server - Automated Deployment" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan

# Configuration
$ProjectName = "mcp-deployment-server"
$DockerImage = "${ProjectName}:latest"
$ComposeFile = "docker-compose.yml"
$EnvFile = ".env"

# Detect platform
Write-Host ""
Write-Host "📍 Platform: Windows" -ForegroundColor Yellow

# Function to check if command exists
function Test-Command($Command) {
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    }
    catch {
        return $false
    }
}

# Check dependencies
Write-Host ""
Write-Host "🔍 Checking dependencies..." -ForegroundColor Yellow

if (Test-Command docker) {
    Write-Host "✅ Docker is installed" -ForegroundColor Green
} else {
    Write-Host "❌ Docker is not installed" -ForegroundColor Red
    Write-Host "Please install Docker: https://docs.docker.com/desktop/windows/wsl/" -ForegroundColor Red
    exit 1
}

# Check if using WSL2
$UseWSL = $false
try {
    wsl --list --verbose | Out-Null
    $UseWSL = $true
    Write-Host "✅ WSL2 is available" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  WSL2 not found, using Docker Desktop" -ForegroundColor Yellow
}

# Load environment variables
if (Test-Path $EnvFile) {
    Write-Host "📄 Loading environment from $EnvFile" -ForegroundColor Yellow
    Get-Content $EnvFile | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
} else {
    Write-Host "⚠️  No .env file found, using defaults" -ForegroundColor Yellow
}

# Choose tunnel solution
if ($Tunnel -eq "prompt") {
    Write-Host ""
    Write-Host "🌐 Choose tunnel solution:" -ForegroundColor Cyan
    Write-Host "1) Cloudflare Tunnel (recommended for production)"
    Write-Host "2) ngrok (quick setup)"
    Write-Host "3) Tailscale (private network)"
    Write-Host "4) None (local only)"
    $TunnelChoice = Read-Host "Enter choice [1-4]"
    
    switch ($TunnelChoice) {
        "1" { $Tunnel = "cloudflare" }
        "2" { $Tunnel = "ngrok" }
        "3" { $Tunnel = "tailscale" }
        "4" { $Tunnel = "none" }
        default { $Tunnel = "none" }
    }
}

# Install tunnel tool if needed
switch ($Tunnel) {
    "cloudflare" {
        if (!(Test-Command cloudflared)) {
            Write-Host "Installing cloudflared..." -ForegroundColor Yellow
            
            if ($UseWSL) {
                wsl bash -c "curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb && sudo dpkg -i cloudflared.deb && rm cloudflared.deb"
            } else {
                $CloudflaredUrl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe"
                $CloudflaredPath = "$env:USERPROFILE\cloudflared.exe"
                Invoke-WebRequest -Uri $CloudflaredUrl -OutFile $CloudflaredPath
                
                # Add to PATH
                $currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
                if ($currentPath -notlike "*$env:USERPROFILE*") {
                    [Environment]::SetEnvironmentVariable("Path", "$currentPath;$env:USERPROFILE", "User")
                    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","User")
                }
            }
        }
    }
    "ngrok" {
        if (!(Test-Command ngrok)) {
            Write-Host "Installing ngrok..." -ForegroundColor Yellow
            Write-Host "Please download from: https://ngrok.com/download" -ForegroundColor Yellow
            Start-Process "https://ngrok.com/download"
            Read-Host "Press Enter after installing ngrok"
        }
    }
    "tailscale" {
        if (!(Test-Command tailscale)) {
            Write-Host "Installing Tailscale..." -ForegroundColor Yellow
            Write-Host "Please download from: https://tailscale.com/download/windows" -ForegroundColor Yellow
            Start-Process "https://tailscale.com/download/windows"
            Read-Host "Press Enter after installing Tailscale"
        }
    }
}

# Build and start
Write-Host ""
Write-Host "🏗️  Building Docker image..." -ForegroundColor Yellow

if ($UseWSL) {
    wsl bash -c "cd $(pwd) && docker compose build"
} else {
    docker compose build
}

Write-Host ""
Write-Host "🛑 Stopping existing containers..." -ForegroundColor Yellow

if ($UseWSL) {
    wsl bash -c "cd $(pwd) && docker compose down"
} else {
    docker compose down
}

Write-Host ""
Write-Host "🚀 Starting MCP server..." -ForegroundColor Yellow

if ($UseWSL) {
    wsl bash -c "cd $(pwd) && docker compose up -d"
} else {
    docker compose up -d
}

# Wait for readiness
Write-Host ""
Write-Host "⏳ Waiting for server to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Health check
Write-Host ""
Write-Host "🏥 Health check..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -UseBasicParsing -ErrorAction Stop
    Write-Host "✅ Server is healthy" -ForegroundColor Green
}
catch {
    Write-Host "⚠️  Server may not be ready yet" -ForegroundColor Yellow
}

# Setup tunnel
Write-Host ""
switch ($Tunnel) {
    "cloudflare" {
        Write-Host "🌐 Starting Cloudflare Tunnel..." -ForegroundColor Cyan
        
        $TunnelId = $env:CLOUDFLARE_TUNNEL_ID
        if ([string]::IsNullOrEmpty($TunnelId)) {
            Write-Host "⚠️  CLOUDFLARE_TUNNEL_ID not set" -ForegroundColor Yellow
            Write-Host "Run: cloudflared tunnel create mcp-deployment-server" -ForegroundColor Yellow
            Write-Host "Then add the tunnel ID to .env" -ForegroundColor Yellow
        } else {
            if ($UseWSL) {
                wsl bash -c "nohup cloudflared tunnel run $TunnelId > /tmp/cloudflared.log 2>&1 &"
            } else {
                Start-Process -FilePath "cloudflared" -ArgumentList "tunnel", "run", $TunnelId -WindowStyle Hidden
            }
            Write-Host "✅ Cloudflare tunnel started" -ForegroundColor Green
            Write-Host "📋 URL: https://mcp.yourdomain.com" -ForegroundColor Cyan
        }
    }
    "ngrok" {
        Write-Host "🌐 Starting ngrok tunnel..." -ForegroundColor Cyan
        
        $NgrokToken = $env:NGROK_AUTH_TOKEN
        if ([string]::IsNullOrEmpty($NgrokToken)) {
            Write-Host "⚠️  NGROK_AUTH_TOKEN not set" -ForegroundColor Yellow
            Write-Host "Get token from: https://dashboard.ngrok.com/get-started/your-authtoken" -ForegroundColor Yellow
        } else {
            ngrok config add-authtoken $NgrokToken
            Start-Process -FilePath "ngrok" -ArgumentList "http", "8080" -WindowStyle Hidden
            Start-Sleep -Seconds 3
            
            try {
                $tunnels = Invoke-RestMethod -Uri "http://localhost:4040/api/tunnels"
                $publicUrl = $tunnels.tunnels[0].public_url
                Write-Host "✅ ngrok tunnel started" -ForegroundColor Green
                Write-Host "📋 URL: $publicUrl" -ForegroundColor Cyan
            }
            catch {
                Write-Host "⚠️  Could not retrieve ngrok URL" -ForegroundColor Yellow
                Write-Host "Check: http://localhost:4040" -ForegroundColor Yellow
            }
        }
    }
    "tailscale" {
        Write-Host "🌐 Configuring Tailscale..." -ForegroundColor Cyan
        
        tailscale up
        $TailscaleIP = (tailscale ip -4)
        Write-Host "✅ Tailscale configured" -ForegroundColor Green
        Write-Host "📋 URL: http://${TailscaleIP}:8080" -ForegroundColor Cyan
    }
    default {
        Write-Host "📋 Server running locally at: http://localhost:8080" -ForegroundColor Cyan
    }
}

# Show status
Write-Host ""
Write-Host "📊 Container status:" -ForegroundColor Yellow

if ($UseWSL) {
    wsl bash -c "cd $(pwd) && docker compose ps"
} else {
    docker compose ps
}

Write-Host ""
Write-Host "📝 View logs with: docker compose logs -f" -ForegroundColor Yellow
Write-Host "🛑 Stop server with: docker compose down" -ForegroundColor Yellow
Write-Host ""
Write-Host "✨ Deployment complete!" -ForegroundColor Green
```

### Make Scripts Executable

```bash
# Linux/WSL2
chmod +x deploy.sh

# Windows (already executable)
```

### Usage

```bash
# Linux/WSL2
./deploy.sh

# Windows PowerShell
.\deploy.ps1

# Or specify tunnel
.\deploy.ps1 -Tunnel cloudflare
```

---

## Adding Self-Deployment to MCP Server

### Tool: Deploy MCP Server Itself

```python
@mcp.tool()
async def deploy_mcp_server(
    platform: str = "docker",
    tunnel: str = "cloudflare",
    auto_start: bool = True
) -> dict:
    """
    Deploy this MCP server itself using Docker and tunneling.
    
    Args:
        platform: Deployment platform (docker, kubernetes)
        tunnel: Tunnel solution (cloudflare, ngrok, tailscale, none)
        auto_start: Whether to start the tunnel automatically
        
    Returns:
        Deployment status and access URLs
    """
    result = {
        "status": "pending",
        "platform": platform,
        "tunnel": tunnel,
        "urls": [],
        "commands_executed": [],
        "next_steps": []
    }
    
    try:
        # 1. Detect operating system
        os_type = detect_os()
        result["os"] = os_type
        
        # 2. Check Docker installation
        if not check_docker_installed():
            result["status"] = "error"
            result["error"] = "Docker not installed"
            result["next_steps"] = get_docker_install_instructions(os_type)
            return result
        
        # 3. Build Docker image
        build_cmd = "docker compose build"
        result["commands_executed"].append(build_cmd)
        build_result = subprocess.run(build_cmd, shell=True, capture_output=True, text=True)
        
        if build_result.returncode != 0:
            result["status"] = "error"
            result["error"] = f"Build failed: {build_result.stderr}"
            return result
        
        # 4. Start container
        start_cmd = "docker compose up -d"
        result["commands_executed"].append(start_cmd)
        start_result = subprocess.run(start_cmd, shell=True, capture_output=True, text=True)
        
        if start_result.returncode != 0:
            result["status"] = "error"
            result["error"] = f"Start failed: {start_result.stderr}"
            return result
        
        result["urls"].append("http://localhost:8080")
        
        # 5. Setup tunnel if requested
        if tunnel != "none" and auto_start:
            tunnel_result = setup_tunnel(tunnel, 8080, os_type)
            result["tunnel_status"] = tunnel_result["status"]
            if tunnel_result.get("url"):
                result["urls"].append(tunnel_result["url"])
        
        result["status"] = "success"
        result["next_steps"] = [
            "Configure Claude Desktop to use this MCP server",
            "Test the connection",
            f"Access at: {', '.join(result['urls'])}"
        ]
        
    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)
    
    return result

def detect_os():
    """Detect operating system"""
    if sys.platform == "win32":
        # Check if running in WSL
        try:
            with open("/proc/version", "r") as f:
                if "microsoft" in f.read().lower():
                    return "WSL2"
        except:
            pass
        return "Windows"
    elif sys.platform == "linux":
        return "Linux"
    elif sys.platform == "darwin":
        return "macOS"
    return "Unknown"

def check_docker_installed():
    """Check if Docker is installed"""
    try:
        result = subprocess.run(["docker", "--version"], capture_output=True, text=True)
        return result.returncode == 0
    except FileNotFoundError:
        return False

def get_docker_install_instructions(os_type):
    """Get Docker installation instructions for the OS"""
    instructions = {
        "Windows": [
            "Option 1 (Recommended): Install Docker in WSL2",
            "  1. Install WSL2: wsl --install",
            "  2. Install Docker in WSL: See Linux instructions",
            "Option 2: Install Docker Desktop (requires license for commercial use)",
            "  Download from: https://www.docker.com/products/docker-desktop"
        ],
        "WSL2": [
            "Install Docker in WSL2:",
            "  curl -fsSL https://get.docker.com -o get-docker.sh",
            "  sudo sh get-docker.sh",
            "  sudo usermod -aG docker $USER",
            "  newgrp docker"
        ],
        "Linux": [
            "Install Docker:",
            "  curl -fsSL https://get.docker.com -o get-docker.sh",
            "  sudo sh get-docker.sh",
            "  sudo usermod -aG docker $USER"
        ],
        "macOS": [
            "Install Docker Desktop:",
            "  Download from: https://www.docker.com/products/docker-desktop"
        ]
    }
    return instructions.get(os_type, ["Unknown OS"])

def setup_tunnel(tunnel_type, port, os_type):
    """Setup tunnel for external access"""
    result = {"status": "pending", "url": None}
    
    try:
        if tunnel_type == "cloudflare":
            # Check if cloudflared is installed
            if not shutil.which("cloudflared"):
                result["status"] = "error"
                result["error"] = "cloudflared not installed"
                result["install_instructions"] = get_cloudflared_install_instructions(os_type)
                return result
            
            # Start tunnel (assumes already configured)
            tunnel_id = os.getenv("CLOUDFLARE_TUNNEL_ID")
            if not tunnel_id:
                result["status"] = "error"
                result["error"] = "CLOUDFLARE_TUNNEL_ID not set"
                return result
            
            cmd = f"cloudflared tunnel run {tunnel_id}"
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            result["status"] = "success"
            result["url"] = f"https://mcp.{os.getenv('CLOUDFLARE_DOMAIN', 'yourdomain.com')}"
            
        elif tunnel_type == "ngrok":
            if not shutil.which("ngrok"):
                result["status"] = "error"
                result["error"] = "ngrok not installed"
                return result
            
            cmd = f"ngrok http {port}"
            subprocess.Popen(cmd, shell=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            time.sleep(3)
            
            # Get ngrok URL
            try:
                import requests
                tunnels = requests.get("http://localhost:4040/api/tunnels").json()
                result["url"] = tunnels["tunnels"][0]["public_url"]
                result["status"] = "success"
            except:
                result["status"] = "partial"
                result["url"] = "Check http://localhost:4040"
        
        elif tunnel_type == "tailscale":
            if not shutil.which("tailscale"):
                result["status"] = "error"
                result["error"] = "tailscale not installed"
                return result
            
            # Get Tailscale IP
            ip_result = subprocess.run(["tailscale", "ip", "-4"], capture_output=True, text=True)
            if ip_result.returncode == 0:
                ip = ip_result.stdout.strip()
                result["url"] = f"http://{ip}:{port}"
                result["status"] = "success"
    
    except Exception as e:
        result["status"] = "error"
        result["error"] = str(e)
    
    return result
```

---

## Production Considerations

### 1. Security Hardening

```yaml
# docker-compose.prod.yml
version: '3.8'

services:
  mcp-server:
    build:
      context: .
      dockerfile: Dockerfile.prod
    
    # Read-only root filesystem
    read_only: true
    
    # Drop all capabilities
    cap_drop:
      - ALL
    
    # Run as non-root
    user: "1000:1000"
    
    # Limited resources
    deploy:
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    
    # Separate networks
    networks:
      - internal
      - external
    
    # Secrets management
    secrets:
      - docker_registry_token
      - k8s_api_token

secrets:
  docker_registry_token:
    external: true
  k8s_api_token:
    external: true

networks:
  internal:
    internal: true
  external:
```

### 2. Monitoring and Logging

```yaml
# Add to docker-compose.yml
services:
  mcp-server:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
    
    labels:
      - "com.datadoghq.ad.logs=[{\"source\":\"mcp-server\",\"service\":\"deployment\"}]"

  # Optional: Add Prometheus exporter
  prometheus:
    image: prom/prometheus
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
    ports:
      - "9090:9090"
```

### 3. Backup and Disaster Recovery

```bash
#!/bin/bash
# backup.sh

# Backup Docker volumes
docker run --rm \
  -v mcp-server-data:/data \
  -v $(pwd)/backups:/backup \
  alpine tar czf /backup/mcp-backup-$(date +%Y%m%d).tar.gz /data

# Backup configuration
tar czf backups/config-backup-$(date +%Y%m%d).tar.gz \
  .env \
  docker-compose.yml \
  ~/.cloudflared/config.yml
```

### 4. Auto-Updates

```bash
#!/bin/bash
# auto-update.sh

# Pull latest image
docker compose pull

# Restart with new image
docker compose up -d

# Clean old images
docker image prune -f
```

### 5. Health Monitoring

```python
# Add health endpoint to your MCP server
from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
async def health():
    """Health check endpoint"""
    checks = {
        "docker": check_docker_connection(),
        "kubernetes": check_k8s_connection(),
        "disk_space": check_disk_space(),
        "memory": check_memory()
    }
    
    all_healthy = all(checks.values())
    
    return {
        "status": "healthy" if all_healthy else "unhealthy",
        "checks": checks,
        "timestamp": datetime.now().isoformat()
    }
```

---

## Troubleshooting

### Common Issues

#### Docker Socket Permission Denied (WSL2)

```bash
# Fix socket permissions
sudo chmod 666 /var/run/docker.sock

# Or add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### Cloudflare Tunnel Not Connecting

```bash
# Check tunnel status
cloudflared tunnel info <tunnel-id>

# Check credentials
ls -la ~/.cloudflared/

# Re-authenticate
cloudflared tunnel login

# Test connection
cloudflared tunnel run <tunnel-id> --loglevel debug
```

#### Port Already in Use

```bash
# Find process using port
# Linux/WSL2
sudo lsof -i :8080
sudo kill -9 <PID>

# Windows
netstat -ano | findstr :8080
taskkill /PID <PID> /F
```

#### Container Won't Start

```bash
# Check logs
docker compose logs -f

# Check container status
docker compose ps

# Restart container
docker compose restart

# Full rebuild
docker compose down
docker compose build --no-cache
docker compose up -d
```

---

## Summary

This guide covered:

✅ **Docker Setup**: WSL2 for Windows, native for Linux  
✅ **Avoiding Docker Desktop**: Lighter, faster alternatives  
✅ **Tunneling**: Cloudflare (production), ngrok (dev), Tailscale (private)  
✅ **Platform Differences**: Windows vs Linux deployment details  
✅ **Automation**: One-command deployment scripts  
✅ **Self-Deployment**: MCP server can deploy itself  
✅ **Production**: Security, monitoring, backups  

Your MCP deployment server is now ready to deploy both itself and other applications!
