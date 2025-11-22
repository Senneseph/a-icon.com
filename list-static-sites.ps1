#!/usr/bin/env pwsh
# List all static sites hosted on the a-icon.com droplet
# Usage: .\list-static-sites.ps1

$ErrorActionPreference = "Stop"

# Load droplet info
if (-not (Test-Path "droplet-info.json")) {
    Write-Host "ERROR: droplet-info.json not found" -ForegroundColor Red
    exit 1
}

$dropletInfo = Get-Content "droplet-info.json" -Raw | ConvertFrom-Json
$DROPLET_IP = $dropletInfo.droplet_ip
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"

Write-Host "=== Static Sites on Droplet $DROPLET_IP ===" -ForegroundColor Green
Write-Host ""

# Get list of Nginx sites
$sitesOutput = ssh -i $SSH_KEY ubuntu@$DROPLET_IP @"
set -e

echo '=== Nginx Sites ==='
ls -1 /etc/nginx/sites-enabled/ 2>/dev/null || echo 'No sites found'

echo ''
echo '=== Site Directories ==='
ls -1 /var/www/ 2>/dev/null || echo 'No directories found'

echo ''
echo '=== SSL Certificates ==='
sudo ls -1 /etc/letsencrypt/live/ 2>/dev/null | grep -v README || echo 'No certificates found'
"@

Write-Host $sitesOutput
Write-Host ""
Write-Host "To view details of a specific site:" -ForegroundColor Yellow
Write-Host "  ssh -i $SSH_KEY ubuntu@$DROPLET_IP 'cat /etc/nginx/sites-available/DOMAIN'" -ForegroundColor White
Write-Host ""

