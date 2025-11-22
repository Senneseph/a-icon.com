#!/usr/bin/env pwsh
# Add static hosting for a domain on the a-icon.com droplet
# Usage: .\add-static-site.ps1 -Domain "example.com" [-Subdomain "www"] [-SourcePath "./dist"]

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [string]$Subdomain = "",
    
    [Parameter(Mandatory=$false)]
    [string]$SourcePath = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipDNS,
    
    [Parameter(Mandatory=$false)]
    [switch]$SkipSSL
)

$ErrorActionPreference = "Stop"

# Check if doctl is available
if (-not (Get-Command doctl -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: doctl (DigitalOcean CLI) is not installed or not in PATH" -ForegroundColor Red
    Write-Host "Install from: https://docs.digitalocean.com/reference/doctl/how-to/install/" -ForegroundColor Yellow
    exit 1
}

# Test doctl authentication (only if not skipping DNS)
if (-not $SkipDNS) {
    try {
        $null = doctl account get 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Authentication failed"
        }
    } catch {
        Write-Host "ERROR: doctl is not authenticated" -ForegroundColor Red
        Write-Host "Run: doctl auth init" -ForegroundColor Yellow
        Write-Host "Or set DO_TOKEN environment variable and run: doctl auth init --access-token `$env:DO_TOKEN" -ForegroundColor Yellow
        exit 1
    }
}

# Load droplet info
if (-not (Test-Path "droplet-info.json")) {
    Write-Host "ERROR: droplet-info.json not found" -ForegroundColor Red
    exit 1
}

$dropletInfo = Get-Content "droplet-info.json" -Raw | ConvertFrom-Json
$DROPLET_IP = $dropletInfo.droplet_ip
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"

# Determine full domain name
$FULL_DOMAIN = if ($Subdomain) { "$Subdomain.$Domain" } else { $Domain }
$SITE_ROOT = "/var/www/$FULL_DOMAIN"

Write-Host "=== Adding Static Site: $FULL_DOMAIN ===" -ForegroundColor Green
Write-Host "Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create DNS record using doctl
if (-not $SkipDNS) {
    Write-Host "[1/5] Creating DNS record..." -ForegroundColor Yellow
    
    $recordName = if ($Subdomain) { $Subdomain } else { "@" }
    
    try {
        # Check if record already exists
        $existingRecords = doctl compute domain records list $Domain --format ID,Name,Data --no-header 2>$null
        $recordExists = $false
        
        if ($existingRecords) {
            foreach ($line in $existingRecords -split "`n") {
                if ($line -match "^\s*(\d+)\s+($recordName)\s+(.+)$") {
                    $recordExists = $true
                    Write-Host "  DNS record already exists for $recordName.$Domain" -ForegroundColor Cyan
                    break
                }
            }
        }
        
        if (-not $recordExists) {
            doctl compute domain records create $Domain `
                --record-type A `
                --record-name $recordName `
                --record-data $DROPLET_IP `
                --record-ttl 300
            Write-Host "  [OK] DNS A record created: $FULL_DOMAIN -> $DROPLET_IP" -ForegroundColor Green
        }
    } catch {
        Write-Host "  WARNING: Could not create DNS record. You may need to create it manually." -ForegroundColor Yellow
        Write-Host "  Error: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "[1/5] Skipping DNS configuration" -ForegroundColor Cyan
}

Write-Host ""

# Step 2: Create site directory on droplet
Write-Host "[2/5] Creating site directory on droplet..." -ForegroundColor Yellow

ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e
sudo mkdir -p $SITE_ROOT
sudo chown -R ubuntu:ubuntu $SITE_ROOT
echo '<!DOCTYPE html>
<html>
<head><title>$FULL_DOMAIN</title></head>
<body>
<h1>Welcome to $FULL_DOMAIN</h1>
<p>This site is hosted on the a-icon.com droplet.</p>
<p>Upload your static files to: $SITE_ROOT</p>
</body>
</html>' > $SITE_ROOT/index.html
"@

Write-Host "  [OK] Site directory created: $SITE_ROOT" -ForegroundColor Green
Write-Host ""

# Step 3: Upload source files if provided
if ($SourcePath -and (Test-Path $SourcePath)) {
    Write-Host "[3/5] Uploading static files..." -ForegroundColor Yellow
    
    scp -i $SSH_KEY -r "$SourcePath/*" ubuntu@${DROPLET_IP}:$SITE_ROOT/
    
    Write-Host "  [OK] Files uploaded from $SourcePath" -ForegroundColor Green
} else {
    Write-Host "[3/5] No source files to upload (placeholder index.html created)" -ForegroundColor Cyan
}

Write-Host ""

# Step 4: Create Nginx configuration
Write-Host "[4/5] Configuring Nginx..." -ForegroundColor Yellow

$nginxConfig = @"
server {
    listen 80;
    server_name $FULL_DOMAIN;

    root $SITE_ROOT;
    index index.html index.htm;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/json application/javascript;

    # Cache static assets
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Try files, fallback to index.html for SPA
    location / {
        try_files `$uri `$uri/ /index.html;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
    }
}
"@

# Write the nginx config to a temp file and upload it (UTF8 without BOM)
$tempNginxFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempNginxFile, $nginxConfig, $utf8NoBom)

scp -i $SSH_KEY $tempNginxFile ubuntu@${DROPLET_IP}:/tmp/nginx-site.conf
Remove-Item $tempNginxFile

ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

# Move nginx config to sites-available
sudo mv /tmp/nginx-site.conf /etc/nginx/sites-available/$FULL_DOMAIN

# Enable the site
sudo ln -sf /etc/nginx/sites-available/$FULL_DOMAIN /etc/nginx/sites-enabled/$FULL_DOMAIN

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
"@

Write-Host "  [OK] Nginx configured and reloaded" -ForegroundColor Green
Write-Host ""

# Step 5: Configure SSL with Let's Encrypt
if (-not $SkipSSL) {
    Write-Host "[5/5] Configuring SSL certificate..." -ForegroundColor Yellow

    ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

# Check if certificate already exists
if [ -f /etc/letsencrypt/live/$FULL_DOMAIN/fullchain.pem ]; then
    echo '  Certificate already exists for $FULL_DOMAIN'
else
    echo '  Obtaining SSL certificate from Let'\''s Encrypt...'
    sudo certbot --nginx -d $FULL_DOMAIN --non-interactive --agree-tos --email admin@$Domain --redirect
    echo '  [OK] SSL certificate obtained and configured'
fi

# Ensure certbot renewal timer is enabled
sudo systemctl enable certbot.timer 2>/dev/null || true
sudo systemctl start certbot.timer 2>/dev/null || true
"@

    Write-Host "  [OK] SSL configured" -ForegroundColor Green
} else {
    Write-Host "[5/5] Skipping SSL configuration" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Static Site Setup Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Site Details:" -ForegroundColor Cyan
Write-Host "  Domain:      $FULL_DOMAIN" -ForegroundColor White
Write-Host "  Root Path:   $SITE_ROOT" -ForegroundColor White
Write-Host "  HTTP URL:    http://$FULL_DOMAIN" -ForegroundColor White
if (-not $SkipSSL) {
    Write-Host "  HTTPS URL:   https://$FULL_DOMAIN" -ForegroundColor White
}
Write-Host ""
Write-Host "To upload files:" -ForegroundColor Yellow
Write-Host "  scp -i $SSH_KEY -r ./your-files/* ubuntu@${DROPLET_IP}:$SITE_ROOT/" -ForegroundColor White
Write-Host ""
Write-Host "To SSH into the droplet:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP" -ForegroundColor White
Write-Host ""
Write-Host "Site files location on droplet:" -ForegroundColor Yellow
Write-Host "  $SITE_ROOT" -ForegroundColor White
Write-Host ""

