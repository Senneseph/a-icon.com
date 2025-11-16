# Remote deployment script for a-icon.com
# This script SSHs into the droplet and deploys the application

$ErrorActionPreference = "Stop"

# Get droplet IP from Terraform output
cd terraform
$DROPLET_IP = (.\terraform.exe output -raw droplet_ip)
cd ..

Write-Host "=== Deploying to a-icon.com ===" -ForegroundColor Green
Write-Host "Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
Write-Host ""

# SSH key path
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"

# Wait for SSH to be available
Write-Host "Waiting for SSH to be available..." -ForegroundColor Yellow
$retries = 0
$maxRetries = 30
while ($retries -lt $maxRetries) {
    try {
        ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$DROPLET_IP "echo 'SSH is ready'"
        if ($LASTEXITCODE -eq 0) {
            Write-Host "SSH connection successful!" -ForegroundColor Green
            break
        }
    } catch {
        # Ignore errors
    }
    $retries++
    Write-Host "Retry $retries/$maxRetries..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
}

if ($retries -eq $maxRetries) {
    Write-Host "ERROR: Could not connect to droplet via SSH" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Deploying application..." -ForegroundColor Green

# Deploy the application
ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

echo '=== Cloning repository ==='
cd /opt/a-icon
sudo chown -R ubuntu:ubuntu /opt/a-icon
git clone https://github.com/Senneseph/a-icon.com.git . || (git fetch origin && git reset --hard origin/master)

echo '=== Building Docker images ==='
docker-compose -f docker-compose.prod.yml build

echo '=== Starting containers ==='
docker-compose -f docker-compose.prod.yml up -d

echo '=== Waiting for services to start ==='
sleep 15

echo '=== Checking container status ==='
docker-compose -f docker-compose.prod.yml ps

echo '=== Configuring SSL with Let's Encrypt ==='
if [ ! -f /etc/letsencrypt/live/a-icon.com/fullchain.pem ]; then
    sudo certbot --nginx -d a-icon.com -d www.a-icon.com --non-interactive --agree-tos --email admin@a-icon.com --redirect
    sudo systemctl enable certbot.timer
    sudo systemctl start certbot.timer
    echo 'SSL certificate configured successfully!'
else
    echo 'SSL certificate already exists'
fi

echo ''
echo '=== Deployment Complete ==='
echo 'Application is now running at:'
echo '  - https://a-icon.com'
echo '  - https://www.a-icon.com'
echo ''
echo 'View logs with: docker-compose -f docker-compose.prod.yml logs -f'
"@

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Green
Write-Host "Application is now running at:" -ForegroundColor Cyan
Write-Host "  - https://a-icon.com" -ForegroundColor White
Write-Host "  - https://www.a-icon.com" -ForegroundColor White
Write-Host ""
Write-Host "To view logs, run:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cd /opt/a-icon && docker-compose -f docker-compose.prod.yml logs -f'" -ForegroundColor White

