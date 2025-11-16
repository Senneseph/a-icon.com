# Deploy a-icon.com using DigitalOcean API directly
# This script creates a droplet with Ubuntu 24.04 LTS and deploys the application

$ErrorActionPreference = "Stop"

# Get DigitalOcean token from environment variable
$DO_TOKEN = $env:DO_TOKEN
if (-not $DO_TOKEN) {
    Write-Host "ERROR: DO_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Set it with: `$env:DO_TOKEN = 'your_token_here'" -ForegroundColor Yellow
    exit 1
}

# Configuration
$SSH_KEY_PATH = "$env:USERPROFILE\.ssh\a-icon-deploy.pub"
$DOMAIN = "a-icon.com"
$REGION = "nyc3"
$SIZE = "s-1vcpu-1gb"

# API Headers
$headers = @{
    "Authorization" = "Bearer $DO_TOKEN"
    "Content-Type" = "application/json"
}

Write-Host "=== Deploying a-icon.com via DigitalOcean API ===" -ForegroundColor Green
Write-Host ""

# Step 1: Get Ubuntu 24.04 LTS image slug
Write-Host "Finding Ubuntu 24.04 LTS image..." -ForegroundColor Cyan
$images = Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/images?type=distribution&per_page=100" -Headers $headers
$ubuntu = $images.images | Where-Object { $_.distribution -eq "Ubuntu" -and $_.name -like "*24.04*LTS*" } | Select-Object -First 1
if (-not $ubuntu) {
    # Fallback to 22.04 LTS
    $ubuntu = $images.images | Where-Object { $_.distribution -eq "Ubuntu" -and $_.name -like "*22.04*LTS*" } | Select-Object -First 1
}
$IMAGE_SLUG = $ubuntu.slug
Write-Host "Using image: $($ubuntu.name) ($IMAGE_SLUG)" -ForegroundColor Green

# Step 2: Get or upload SSH key
Write-Host "Getting SSH key..." -ForegroundColor Cyan
$sshKeyContent = Get-Content $SSH_KEY_PATH -Raw
$sshKeyContent = $sshKeyContent.Trim()

# Try to find existing key
$existingKeys = Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/account/keys" -Headers $headers
$existingKey = $existingKeys.ssh_keys | Where-Object { $_.public_key.Trim() -eq $sshKeyContent }

if ($existingKey) {
    $SSH_KEY_ID = $existingKey.id
    Write-Host "Using existing SSH key: ID $SSH_KEY_ID" -ForegroundColor Green
} else {
    # Upload new key
    $sshKeyBody = @{
        name = "a-icon-deploy-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        public_key = $sshKeyContent
    } | ConvertTo-Json

    $sshKeyResponse = Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/account/keys" -Method Post -Headers $headers -Body $sshKeyBody
    $SSH_KEY_ID = $sshKeyResponse.ssh_key.id
    Write-Host "SSH key uploaded: ID $SSH_KEY_ID" -ForegroundColor Green
}

# Step 3: Create cloud-init user data
$USER_DATA = @"
#cloud-config

package_update: true
package_upgrade: true

packages:
  - docker.io
  - docker-compose
  - nginx
  - certbot
  - python3-certbot-nginx
  - git
  - curl

users:
  - name: ubuntu
    ssh_authorized_keys:
      - $sshKeyContent
    sudo: ['ALL=(ALL) NOPASSWD:ALL']
    groups: sudo, docker
    shell: /bin/bash

runcmd:
  - systemctl enable docker
  - systemctl start docker
  - usermod -aG docker ubuntu
  - mkdir -p /opt/a-icon/data
  - chown -R ubuntu:ubuntu /opt/a-icon
  - rm -f /etc/nginx/sites-enabled/default
  - |
    cat > /etc/nginx/sites-available/a-icon.com <<'EOF'
    server {
        listen 80;
        server_name $DOMAIN www.$DOMAIN;
        client_max_body_size 10M;
        
        location / {
            proxy_pass http://localhost:4200;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host `$host;
            proxy_cache_bypass `$http_upgrade;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
        }
        
        location /api {
            proxy_pass http://localhost:3000;
            proxy_http_version 1.1;
            proxy_set_header Upgrade `$http_upgrade;
            proxy_set_header Connection 'upgrade';
            proxy_set_header Host `$host;
            proxy_cache_bypass `$http_upgrade;
            proxy_set_header X-Real-IP `$remote_addr;
            proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto `$scheme;
        }
    }
    EOF
  - ln -s /etc/nginx/sites-available/a-icon.com /etc/nginx/sites-enabled/
  - nginx -t && systemctl restart nginx
  - echo "Cloud-init complete" > /var/log/cloud-init-done.log
"@

# Step 4: Create droplet
Write-Host "Creating droplet..." -ForegroundColor Cyan
$dropletBody = @{
    name = "a-icon-app"
    region = $REGION
    size = $SIZE
    image = $IMAGE_SLUG
    ssh_keys = @($SSH_KEY_ID)
    backups = $false
    ipv6 = $false
    monitoring = $false
    tags = @("a-icon", "production")
    user_data = $USER_DATA
} | ConvertTo-Json

$dropletResponse = Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/droplets" -Method Post -Headers $headers -Body $dropletBody
$DROPLET_ID = $dropletResponse.droplet.id
Write-Host "Droplet created: ID $DROPLET_ID" -ForegroundColor Green

# Step 5: Wait for droplet to be active
Write-Host "Waiting for droplet to become active..." -ForegroundColor Yellow
$maxRetries = 60
$retries = 0
do {
    Start-Sleep -Seconds 5
    $droplet = Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/droplets/$DROPLET_ID" -Headers $headers
    $status = $droplet.droplet.status
    Write-Host "  Status: $status" -ForegroundColor Gray
    $retries++
} while ($status -ne "active" -and $retries -lt $maxRetries)

if ($status -ne "active") {
    Write-Host "ERROR: Droplet did not become active in time" -ForegroundColor Red
    exit 1
}

$DROPLET_IP = $droplet.droplet.networks.v4 | Where-Object { $_.type -eq "public" } | Select-Object -First 1 -ExpandProperty ip_address
Write-Host "Droplet is active! IP: $DROPLET_IP" -ForegroundColor Green

# Save droplet info
@{
    droplet_id = $DROPLET_ID
    droplet_ip = $DROPLET_IP
    ssh_key_id = $SSH_KEY_ID
} | ConvertTo-Json | Out-File -FilePath "droplet-info.json"

Write-Host ""
Write-Host "Droplet created successfully!" -ForegroundColor Green
Write-Host "  ID: $DROPLET_ID" -ForegroundColor White
Write-Host "  IP: $DROPLET_IP" -ForegroundColor White
Write-Host ""
Write-Host "Next: Creating DNS records and deploying application..." -ForegroundColor Cyan

