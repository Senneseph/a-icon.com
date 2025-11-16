# Part 2: Create DNS records and deploy application
# Run this after deploy-api.ps1

$ErrorActionPreference = "Stop"

# Get DigitalOcean token from environment variable
$DO_TOKEN = $env:DO_TOKEN
if (-not $DO_TOKEN) {
    Write-Host "ERROR: DO_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Set it with: `$env:DO_TOKEN = 'your_token_here'" -ForegroundColor Yellow
    exit 1
}

# Configuration
$DOMAIN = "a-icon.com"
$SSH_KEY_PATH = "$env:USERPROFILE\.ssh\a-icon-deploy"

# Load droplet info
if (-not (Test-Path "droplet-info.json")) {
    Write-Host "ERROR: droplet-info.json not found. Run deploy-api.ps1 first." -ForegroundColor Red
    exit 1
}

$dropletInfo = Get-Content "droplet-info.json" | ConvertFrom-Json
$DROPLET_IP = $dropletInfo.droplet_ip
$DROPLET_ID = $dropletInfo.droplet_id

Write-Host "=== Configuring DNS and Deploying Application ===" -ForegroundColor Green
Write-Host "Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
Write-Host ""

# API Headers
$headers = @{
    "Authorization" = "Bearer $DO_TOKEN"
    "Content-Type" = "application/json"
}

# Step 1: Create DNS records
Write-Host "Creating DNS records..." -ForegroundColor Cyan

# Root domain
$dnsBody = @{
    type = "A"
    name = "@"
    data = $DROPLET_IP
    ttl = 300
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/domains/$DOMAIN/records" -Method Post -Headers $headers -Body $dnsBody | Out-Null
    Write-Host "  Created: $DOMAIN -> $DROPLET_IP" -ForegroundColor Green
} catch {
    Write-Host "  Note: Root record may already exist" -ForegroundColor Yellow
}

# WWW subdomain
$dnsBody = @{
    type = "A"
    name = "www"
    data = $DROPLET_IP
    ttl = 300
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/domains/$DOMAIN/records" -Method Post -Headers $headers -Body $dnsBody | Out-Null
    Write-Host "  Created: www.$DOMAIN -> $DROPLET_IP" -ForegroundColor Green
} catch {
    Write-Host "  Note: WWW record may already exist" -ForegroundColor Yellow
}

# API subdomain
$dnsBody = @{
    type = "A"
    name = "api"
    data = $DROPLET_IP
    ttl = 300
} | ConvertTo-Json

try {
    Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/domains/$DOMAIN/records" -Method Post -Headers $headers -Body $dnsBody | Out-Null
    Write-Host "  Created: api.$DOMAIN -> $DROPLET_IP" -ForegroundColor Green
} catch {
    Write-Host "  Note: API record may already exist" -ForegroundColor Yellow
}

# Step 2: Wait for SSH to be available
Write-Host ""
Write-Host "Waiting for SSH to be available..." -ForegroundColor Yellow
$maxRetries = 30
$retries = 0
$sshReady = $false

while ($retries -lt $maxRetries -and -not $sshReady) {
    try {
        $result = ssh -i $SSH_KEY_PATH -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$DROPLET_IP "echo 'SSH ready'" 2>&1
        if ($LASTEXITCODE -eq 0) {
            $sshReady = $true
            Write-Host "SSH connection successful!" -ForegroundColor Green
        }
    } catch {
        # Ignore
    }
    
    if (-not $sshReady) {
        $retries++
        Write-Host "  Retry $retries/$maxRetries..." -ForegroundColor Gray
        Start-Sleep -Seconds 10
    }
}

if (-not $sshReady) {
    Write-Host "ERROR: Could not connect via SSH" -ForegroundColor Red
    exit 1
}

# Step 3: Wait for cloud-init to complete
Write-Host ""
Write-Host "Waiting for cloud-init to complete..." -ForegroundColor Yellow
ssh -i $SSH_KEY_PATH ubuntu@$DROPLET_IP "cloud-init status --wait"
Write-Host "Cloud-init complete!" -ForegroundColor Green

# Step 4: Deploy application
Write-Host ""
Write-Host "Deploying application..." -ForegroundColor Cyan

$deployScript = @'
set -e
cd /opt/a-icon
sudo chown -R ubuntu:ubuntu /opt/a-icon
git clone https://github.com/Senneseph/a-icon.com.git . || (git fetch origin && git reset --hard origin/master)
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d
sleep 15
docker-compose -f docker-compose.prod.yml ps
'@

ssh -i $SSH_KEY_PATH ubuntu@$DROPLET_IP $deployScript

# Step 5: Configure SSL
Write-Host ""
Write-Host "Configuring SSL certificate..." -ForegroundColor Cyan

$sslScript = @"
if [ ! -f /etc/letsencrypt/live/$DOMAIN/fullchain.pem ]; then
    sudo certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN --redirect
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    echo 'SSL configured successfully!'
else
    echo 'SSL certificate already exists'
fi
"@

ssh -i $SSH_KEY_PATH ubuntu@$DROPLET_IP $sslScript

Write-Host ""
Write-Host "=== Deployment Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Application is now running at:" -ForegroundColor Cyan
Write-Host "  - https://$DOMAIN" -ForegroundColor White
Write-Host "  - https://www.$DOMAIN" -ForegroundColor White
Write-Host ""
Write-Host "Test the API:" -ForegroundColor Yellow
Write-Host "  curl https://$DOMAIN/api/health" -ForegroundColor White

