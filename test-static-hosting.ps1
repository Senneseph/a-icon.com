#!/usr/bin/env pwsh
# Test the static hosting setup
# This script verifies all prerequisites and creates a test site

$ErrorActionPreference = "Stop"

Write-Host "=== Static Hosting Setup Test ===" -ForegroundColor Green
Write-Host ""

# Test 1: Check doctl
Write-Host "[1/6] Checking doctl installation..." -ForegroundColor Yellow
if (Get-Command doctl -ErrorAction SilentlyContinue) {
    $doctlVersion = doctl version
    Write-Host "  ✓ doctl is installed: $doctlVersion" -ForegroundColor Green
} else {
    Write-Host "  ✗ doctl is not installed" -ForegroundColor Red
    Write-Host "  Install from: https://docs.digitalocean.com/reference/doctl/how-to/install/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Test 2: Check doctl authentication
Write-Host "[2/6] Checking doctl authentication..." -ForegroundColor Yellow
try {
    $account = doctl account get --format Email --no-header 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ doctl is authenticated: $account" -ForegroundColor Green
    } else {
        throw "Not authenticated"
    }
} catch {
    Write-Host "  ✗ doctl is not authenticated" -ForegroundColor Red
    Write-Host "  Run: doctl auth init" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Test 3: Check droplet info
Write-Host "[3/6] Checking droplet info..." -ForegroundColor Yellow
if (Test-Path "droplet-info.json") {
    $dropletInfo = Get-Content "droplet-info.json" -Raw | ConvertFrom-Json
    $DROPLET_IP = $dropletInfo.droplet_ip
    Write-Host "  ✓ droplet-info.json found" -ForegroundColor Green
    Write-Host "    Droplet IP: $DROPLET_IP" -ForegroundColor Cyan
} else {
    Write-Host "  ✗ droplet-info.json not found" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 4: Check SSH key
Write-Host "[4/6] Checking SSH key..." -ForegroundColor Yellow
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"
if (Test-Path $SSH_KEY) {
    Write-Host "  ✓ SSH key found: $SSH_KEY" -ForegroundColor Green
} else {
    Write-Host "  ✗ SSH key not found: $SSH_KEY" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 5: Check SSH connection
Write-Host "[5/6] Testing SSH connection..." -ForegroundColor Yellow
try {
    $sshTest = ssh -i $SSH_KEY -o ConnectTimeout=10 -o StrictHostKeyChecking=no ubuntu@$DROPLET_IP "echo 'SSH OK'" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ SSH connection successful" -ForegroundColor Green
    } else {
        throw "SSH failed"
    }
} catch {
    Write-Host "  ✗ SSH connection failed" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Test 6: List available domains
Write-Host "[6/6] Listing available domains..." -ForegroundColor Yellow
try {
    $domains = doctl compute domain list --format Domain --no-header 2>&1
    if ($LASTEXITCODE -eq 0 -and $domains) {
        Write-Host "  ✓ Available domains:" -ForegroundColor Green
        foreach ($domain in $domains -split "`n") {
            if ($domain.Trim()) {
                Write-Host "    - $($domain.Trim())" -ForegroundColor Cyan
            }
        }
    } else {
        Write-Host "  ⚠ No domains found in DigitalOcean account" -ForegroundColor Yellow
        Write-Host "    You can still use the scripts with -SkipDNS flag" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠ Could not list domains" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "=== All Tests Passed! ===" -ForegroundColor Green
Write-Host ""
Write-Host "You're ready to add static sites!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Example commands:" -ForegroundColor Yellow
Write-Host "  # Add a domain" -ForegroundColor White
Write-Host "  .\add-static-site.ps1 -Domain 'iffuso.com'" -ForegroundColor White
Write-Host ""
Write-Host "  # Add a subdomain with files" -ForegroundColor White
Write-Host "  .\add-static-site.ps1 -Domain 'iffuso.com' -Subdomain 'www' -SourcePath './dist'" -ForegroundColor White
Write-Host ""
Write-Host "  # List all sites" -ForegroundColor White
Write-Host "  .\list-static-sites.ps1" -ForegroundColor White
Write-Host ""
Write-Host "For more examples, see STATIC-HOSTING-SETUP.md" -ForegroundColor Cyan
Write-Host ""

