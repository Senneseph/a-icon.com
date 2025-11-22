#!/usr/bin/env pwsh
# Remove static hosting for a domain from the a-icon.com droplet
# Usage: .\remove-static-site.ps1 -Domain "example.com" [-Subdomain "www"]

param(
    [Parameter(Mandatory=$true)]
    [string]$Domain,
    
    [Parameter(Mandatory=$false)]
    [string]$Subdomain = "",
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepDNS,
    
    [Parameter(Mandatory=$false)]
    [switch]$KeepFiles
)

$ErrorActionPreference = "Stop"

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

Write-Host "=== Removing Static Site: $FULL_DOMAIN ===" -ForegroundColor Yellow
Write-Host "Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
Write-Host ""

# Confirm deletion
$confirmation = Read-Host "Are you sure you want to remove $FULL_DOMAIN? (yes/no)"
if ($confirmation -ne "yes") {
    Write-Host "Aborted." -ForegroundColor Yellow
    exit 0
}

Write-Host ""

# Step 1: Remove Nginx configuration
Write-Host "[1/4] Removing Nginx configuration..." -ForegroundColor Yellow

ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

# Disable the site
sudo rm -f /etc/nginx/sites-enabled/$FULL_DOMAIN

# Remove configuration file
sudo rm -f /etc/nginx/sites-available/$FULL_DOMAIN

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx
"@

Write-Host "  ✓ Nginx configuration removed" -ForegroundColor Green
Write-Host ""

# Step 2: Revoke SSL certificate
Write-Host "[2/4] Revoking SSL certificate..." -ForegroundColor Yellow

ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

if [ -d /etc/letsencrypt/live/$FULL_DOMAIN ]; then
    echo '  Revoking certificate...'
    sudo certbot revoke --cert-path /etc/letsencrypt/live/$FULL_DOMAIN/cert.pem --non-interactive || true
    sudo certbot delete --cert-name $FULL_DOMAIN --non-interactive || true
    echo '  ✓ Certificate revoked'
else
    echo '  No certificate found'
fi
"@

Write-Host "  ✓ SSL certificate handled" -ForegroundColor Green
Write-Host ""

# Step 3: Remove site files
if (-not $KeepFiles) {
    Write-Host "[3/4] Removing site files..." -ForegroundColor Yellow
    
    ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e
sudo rm -rf $SITE_ROOT
"@
    
    Write-Host "  ✓ Site files removed from $SITE_ROOT" -ForegroundColor Green
} else {
    Write-Host "[3/4] Keeping site files at $SITE_ROOT" -ForegroundColor Cyan
}

Write-Host ""

# Step 4: Remove DNS record
if (-not $KeepDNS) {
    Write-Host "[4/4] Removing DNS record..." -ForegroundColor Yellow
    
    $recordName = if ($Subdomain) { $Subdomain } else { "@" }
    
    try {
        # Find and delete the DNS record
        $records = doctl compute domain records list $Domain --format ID,Name,Type --no-header 2>$null
        
        if ($records) {
            foreach ($line in $records -split "`n") {
                if ($line -match "^\s*(\d+)\s+($recordName)\s+A\s*$") {
                    $recordId = $matches[1]
                    doctl compute domain records delete $Domain $recordId --force
                    Write-Host "  ✓ DNS record removed" -ForegroundColor Green
                    break
                }
            }
        }
    } catch {
        Write-Host "  WARNING: Could not remove DNS record automatically" -ForegroundColor Yellow
        Write-Host "  You may need to remove it manually from DigitalOcean dashboard" -ForegroundColor Yellow
    }
} else {
    Write-Host "[4/4] Keeping DNS record" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Static Site Removed ===" -ForegroundColor Green
Write-Host ""
Write-Host "Site $FULL_DOMAIN has been removed from the droplet." -ForegroundColor White
Write-Host ""

