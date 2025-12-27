# Deploy Rust Edge Gateway to DigitalOcean droplet
# The gateway compiles handlers dynamically via its Admin API

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying Rust Edge Gateway to DigitalOcean ===" -ForegroundColor Green
Write-Host ""

# Load environment variables from .env file
if (Test-Path ".env") {
    Write-Host "Loading environment variables from .env..." -ForegroundColor Cyan
    Get-Content ".env" | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]*)\s*=\s*"?([^"]*)"?\s*$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
} else {
    Write-Host "WARNING: .env file not found" -ForegroundColor Yellow
}

# Get droplet info
if (-not (Test-Path "droplet-info.json")) {
    Write-Host "ERROR: droplet-info.json not found" -ForegroundColor Red
    exit 1
}

$dropletInfo = Get-Content "droplet-info.json" -Raw | ConvertFrom-Json
$DROPLET_IP = $dropletInfo.droplet_ip

Write-Host "Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
Write-Host ""

# SSH key path
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"

if (-not (Test-Path $SSH_KEY)) {
    Write-Host "ERROR: SSH key not found at $SSH_KEY" -ForegroundColor Red
    exit 1
}

# Step 1: Transfer files to droplet
Write-Host ""
Write-Host "=== Step 1: Transferring files to droplet ===" -ForegroundColor Green
Write-Host ""

Write-Host "Transferring docker-compose.prod.yml..." -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no docker-compose.prod.yml ubuntu@${DROPLET_IP}:/tmp/docker-compose.prod.yml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to transfer docker-compose file" -ForegroundColor Red
    exit 1
}

Write-Host "Transferring setup scripts..." -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no scripts/setup-gateway.sh ubuntu@${DROPLET_IP}:/tmp/setup-gateway.sh
scp -i $SSH_KEY -o StrictHostKeyChecking=no scripts/setup-sqlite-service.sh ubuntu@${DROPLET_IP}:/tmp/setup-sqlite-service.sh

# Step 2: Deploy gateway on droplet
Write-Host ""
Write-Host "=== Step 2: Deploying Rust Edge Gateway ===" -ForegroundColor Green
Write-Host ""

ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

echo '=== Pulling Rust Edge Gateway image ==='
docker pull ghcr.io/senneseph/rust-edge-gateway:latest

echo ''
echo '=== Setting up application directory ==='
sudo mkdir -p /opt/a-icon
sudo chown -R ubuntu:ubuntu /opt/a-icon
cd /opt/a-icon

echo ''
echo '=== Copying files ==='
cp /tmp/docker-compose.prod.yml docker-compose.prod.yml
cp /tmp/setup-gateway.sh setup-gateway.sh
cp /tmp/setup-sqlite-service.sh setup-sqlite-service.sh
chmod +x setup-gateway.sh setup-sqlite-service.sh

echo ''
echo '=== Stopping old containers ==='
docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

echo ''
echo '=== Starting gateway ==='
docker-compose -f docker-compose.prod.yml up -d rust-edge-gateway

echo ''
echo '=== Waiting for gateway to start ==='
sleep 15

echo ''
echo '=== Container status ==='
docker-compose -f docker-compose.prod.yml ps

echo ''
echo '=== Checking Admin API health ==='
curl -s http://localhost:8081/api/health || echo 'Admin API not ready yet...'

echo ''
echo '=== Cleaning up temp files ==='
rm -f /tmp/docker-compose.prod.yml /tmp/setup-gateway.sh /tmp/setup-sqlite-service.sh

echo ''
echo '=== Gateway Deployment Complete ==='
"@

Write-Host ""
Write-Host "=== Gateway Deployed ===" -ForegroundColor Green
Write-Host ""
Write-Host "Gateway is running at:" -ForegroundColor Cyan
Write-Host "  - http://$DROPLET_IP:8080 (Gateway API)" -ForegroundColor White
Write-Host "  - http://$DROPLET_IP:8081 (Admin API/UI)" -ForegroundColor White
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. SSH into droplet: ssh -i $SSH_KEY ubuntu@$DROPLET_IP" -ForegroundColor White
Write-Host "  2. Run setup script: cd /opt/a-icon && ./setup-gateway.sh" -ForegroundColor White
Write-Host "  3. Run SQLite setup: ./setup-sqlite-service.sh" -ForegroundColor White
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cd /opt/a-icon && docker-compose -f docker-compose.prod.yml logs -f rust-edge-gateway'" -ForegroundColor White
Write-Host ""

