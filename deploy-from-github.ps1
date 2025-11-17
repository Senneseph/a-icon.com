# Deploy a-icon.com by cloning from GitHub and building on the droplet
# This avoids large file transfers

$ErrorActionPreference = "Stop"

Write-Host "=== Deploying a-icon.com from GitHub ===" -ForegroundColor Green
Write-Host ""

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

# Test SSH connection
Write-Host "Testing SSH connection..." -ForegroundColor Yellow
try {
    ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$DROPLET_IP "echo 'SSH OK'" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERROR: Cannot connect to droplet via SSH" -ForegroundColor Red
        exit 1
    }
    Write-Host "SSH connection successful!" -ForegroundColor Green
} catch {
    Write-Host "ERROR: SSH connection failed: $_" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deploying application from GitHub..." -ForegroundColor Green
Write-Host ""

# Generate admin password if not exists
$ADMIN_PASSWORD_FILE = ".admin-password"
if (-not (Test-Path $ADMIN_PASSWORD_FILE)) {
    Write-Host "Generating admin password..." -ForegroundColor Yellow
    $ADMIN_PASSWORD = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object {[char]$_})
    Set-Content -Path $ADMIN_PASSWORD_FILE -Value $ADMIN_PASSWORD -NoNewline
    Write-Host "Admin password generated and saved to $ADMIN_PASSWORD_FILE" -ForegroundColor Green
} else {
    Write-Host "Using existing admin password from $ADMIN_PASSWORD_FILE" -ForegroundColor Cyan
    $ADMIN_PASSWORD = Get-Content -Path $ADMIN_PASSWORD_FILE -Raw
}

Write-Host ""

# Deploy the application
ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

echo '=== Setting up application directory ==='
sudo mkdir -p /opt/a-icon
sudo chown -R ubuntu:ubuntu /opt/a-icon
cd /opt/a-icon

echo ''
echo '=== Cloning/updating repository from GitHub ==='
if [ -d .git ]; then
    echo 'Repository exists, pulling latest changes...'
    git fetch origin
    git reset --hard origin/master
    git pull origin master
else
    echo 'Cloning repository...'
    git clone https://github.com/Senneseph/a-icon.com.git .
fi

echo ''
echo '=== Current commit ==='
git log -1 --oneline

echo ''
echo '=== Building Docker images on droplet ==='
docker-compose -f docker-compose.prod.yml build --no-cache

echo ''
echo '=== Stopping and removing old containers ==='
docker-compose -f docker-compose.prod.yml down
docker rm -f a-icon-api a-icon-web 2>/dev/null || true

echo ''
echo '=== Creating data directory ==='
mkdir -p data

echo ''
echo '=== Setting admin password ==='
echo "ADMIN_PASSWORD=$ADMIN_PASSWORD" > .env

echo ''
echo '=== Starting new containers ==='
docker-compose -f docker-compose.prod.yml up -d

echo ''
echo '=== Waiting for services to start ==='
sleep 15

echo ''
echo '=== Container status ==='
docker-compose -f docker-compose.prod.yml ps

echo ''
echo '=== Checking API health ==='
curl -f http://localhost:3000/api/health || echo 'API health check failed (may need more time)'

echo ''
echo '=== Checking container logs ==='
docker-compose -f docker-compose.prod.yml logs --tail=20

echo ''
echo '=== Deployment Complete ==='
"@

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
Write-Host "To check status:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cd /opt/a-icon && docker-compose -f docker-compose.prod.yml ps'" -ForegroundColor White
Write-Host ""

