# Build Docker images locally and deploy to DigitalOcean droplet
# This script builds images locally, saves them as tar files, transfers to droplet, and loads them

$ErrorActionPreference = "Stop"

Write-Host "=== Building and Deploying Docker Images to DigitalOcean ===" -ForegroundColor Green
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

# Step 1: Build Docker images locally
Write-Host "=== Step 1: Building Docker images locally ===" -ForegroundColor Green
Write-Host ""

Write-Host "Building API image..." -ForegroundColor Cyan
docker build -t a-icon-api:latest ./a-icon-api
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build API image" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Building Web image..." -ForegroundColor Cyan
docker build -t a-icon-web:latest --build-arg API_URL= ./a-icon-web
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to build Web image" -ForegroundColor Red
    exit 1
}

# Step 2: Save Docker images to tar files
Write-Host ""
Write-Host "=== Step 2: Saving Docker images to tar files ===" -ForegroundColor Green
Write-Host ""

Write-Host "Saving API image..." -ForegroundColor Cyan
docker save a-icon-api:latest -o a-icon-api.tar
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to save API image" -ForegroundColor Red
    exit 1
}

Write-Host "Saving Web image..." -ForegroundColor Cyan
docker save a-icon-web:latest -o a-icon-web.tar
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to save Web image" -ForegroundColor Red
    exit 1
}

$apiSize = (Get-Item a-icon-api.tar).Length / 1MB
$webSize = (Get-Item a-icon-web.tar).Length / 1MB
Write-Host "API image size: $([math]::Round($apiSize, 2)) MB" -ForegroundColor Gray
Write-Host "Web image size: $([math]::Round($webSize, 2)) MB" -ForegroundColor Gray

# Step 3: Transfer tar files to droplet
Write-Host ""
Write-Host "=== Step 3: Transferring images to droplet ===" -ForegroundColor Green
Write-Host ""

Write-Host "Transferring API image..." -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no a-icon-api.tar ubuntu@${DROPLET_IP}:/tmp/a-icon-api.tar
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to transfer API image" -ForegroundColor Red
    exit 1
}

Write-Host "Transferring Web image..." -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no a-icon-web.tar ubuntu@${DROPLET_IP}:/tmp/a-icon-web.tar
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to transfer Web image" -ForegroundColor Red
    exit 1
}

Write-Host "Transferring docker-compose.prod.yml..." -ForegroundColor Cyan
scp -i $SSH_KEY -o StrictHostKeyChecking=no docker-compose.prod.yml ubuntu@${DROPLET_IP}:/tmp/docker-compose.prod.yml
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: Failed to transfer docker-compose file" -ForegroundColor Red
    exit 1
}

# Step 4: Load images and start containers on droplet
Write-Host ""
Write-Host "=== Step 4: Loading images and starting containers ===" -ForegroundColor Green
Write-Host ""

ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

echo '=== Loading Docker images ==='
docker load -i /tmp/a-icon-api.tar
docker load -i /tmp/a-icon-web.tar

echo ''
echo '=== Setting up application directory ==='
sudo mkdir -p /opt/a-icon
sudo chown -R ubuntu:ubuntu /opt/a-icon
cd /opt/a-icon

echo ''
echo '=== Copying docker-compose file ==='
cp /tmp/docker-compose.prod.yml docker-compose.prod.yml

echo ''
echo '=== Creating data directory ==='
mkdir -p data

echo ''
echo '=== Stopping old containers ==='
docker-compose -f docker-compose.prod.yml down 2>/dev/null || true

echo ''
echo '=== Starting new containers ==='
docker-compose -f docker-compose.prod.yml up -d

echo ''
echo '=== Waiting for services to start ==='
sleep 10

echo ''
echo '=== Container status ==='
docker-compose -f docker-compose.prod.yml ps

echo ''
echo '=== Cleaning up tar files ==='
rm -f /tmp/a-icon-api.tar /tmp/a-icon-web.tar /tmp/docker-compose.prod.yml

echo ''
echo '=== Deployment Complete ==='
"@

# Clean up local tar files
Write-Host ""
Write-Host "Cleaning up local tar files..." -ForegroundColor Cyan
Remove-Item a-icon-api.tar -ErrorAction SilentlyContinue
Remove-Item a-icon-web.tar -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Application is running at:" -ForegroundColor Cyan
Write-Host "  - http://$DROPLET_IP:4200 (Web)" -ForegroundColor White
Write-Host "  - http://$DROPLET_IP:3000 (API)" -ForegroundColor White
Write-Host ""
Write-Host "To view logs:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cd /opt/a-icon && docker-compose -f docker-compose.prod.yml logs -f'" -ForegroundColor White
Write-Host ""

