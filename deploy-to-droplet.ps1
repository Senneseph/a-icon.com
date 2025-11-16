# Deploy a-icon.com to existing DigitalOcean droplet
# This script loads .env and deploys the application

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying a-icon.com to DigitalOcean ===" -ForegroundColor Green
Write-Host ""

# Load environment variables from .env file
if (Test-Path ".env") {
    Write-Host "Loading environment variables from .env..." -ForegroundColor Cyan
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*"?([^"]*)"?\s*$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
            Write-Host "  Loaded: $name" -ForegroundColor Gray
        }
    }
} else {
    Write-Host "ERROR: .env file not found" -ForegroundColor Red
    Write-Host "Create a .env file with: DO_TOKEN=your_token_here" -ForegroundColor Yellow
    exit 1
}

# Verify DO_TOKEN is set
if (-not $env:DO_TOKEN) {
    Write-Host "ERROR: DO_TOKEN not found in .env file" -ForegroundColor Red
    exit 1
}

# Get droplet info
if (-not (Test-Path "droplet-info.json")) {
    Write-Host "ERROR: droplet-info.json not found" -ForegroundColor Red
    exit 1
}

$dropletInfo = Get-Content "droplet-info.json" -Raw | ConvertFrom-Json
$DROPLET_IP = $dropletInfo.droplet_ip

Write-Host ""
Write-Host "Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
Write-Host ""

# SSH key path
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"

if (-not (Test-Path $SSH_KEY)) {
    Write-Host "ERROR: SSH key not found at $SSH_KEY" -ForegroundColor Red
    exit 1
}

# Test SSH connection
Write-Host "Testing SSH connection..." -ForegroundColor Yellow
try {
    $result = ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$DROPLET_IP "echo 'SSH OK'" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Cannot connect to droplet via SSH" -ForegroundColor Red
        Write-Host $result -ForegroundColor Red
        exit 1
    }
    Write-Host "SSH connection successful!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: SSH connection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deploying application..." -ForegroundColor Green
Write-Host ""

# Deploy the application
ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

echo '=== Updating repository ==='
cd /opt/a-icon || (sudo mkdir -p /opt/a-icon && sudo chown -R ubuntu:ubuntu /opt/a-icon && cd /opt/a-icon)

if [ -d .git ]; then
    echo 'Repository exists, pulling latest changes...'
    git fetch origin
    git reset --hard origin/master
else
    echo 'Cloning repository...'
    git clone https://github.com/Senneseph/a-icon.com.git .
fi

echo ''
echo '=== Building Docker images ==='
docker-compose -f docker-compose.prod.yml build

echo ''
echo '=== Stopping old containers ==='
docker-compose -f docker-compose.prod.yml down

echo ''
echo '=== Starting new containers ==='
docker-compose -f docker-compose.prod.yml up -d

echo ''
echo '=== Waiting for services to start ==='
sleep 10

echo ''
echo '=== Checking container status ==='
docker-compose -f docker-compose.prod.yml ps

echo ''
echo '=== Checking API health ==='
sleep 5
curl -f http://localhost:3000/api/health || echo 'API health check failed (may need more time)'

echo ''
echo '=== Deployment Complete ==='
"@

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Application should be running at:" -ForegroundColor Cyan
Write-Host "  - http://$DROPLET_IP:4200 (Web)" -ForegroundColor White
Write-Host "  - http://$DROPLET_IP:3000 (API)" -ForegroundColor White
Write-Host ""
Write-Host "To view logs, run:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cd /opt/a-icon && docker-compose -f docker-compose.prod.yml logs -f'" -ForegroundColor White
Write-Host ""
Write-Host "To check status:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cd /opt/a-icon && docker-compose -f docker-compose.prod.yml ps'" -ForegroundColor White
Write-Host ""

