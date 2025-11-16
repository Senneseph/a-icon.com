#!/usr/bin/env pwsh

# Deploy a-icon.com application to DigitalOcean droplet
# This script saves Docker images as tar files, transfers them to the droplet,
# loads them, and runs the containers

$ErrorActionPreference = "Stop"

$DROPLET_IP = "167.71.191.234"
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"
$SSH_USER = "ubuntu"

Write-Host "=== Deploying a-icon.com to DigitalOcean ===" -ForegroundColor Cyan

# Step 1: Save Docker images as tar files
Write-Host "`n[1/6] Saving Docker images as tar files..." -ForegroundColor Yellow
docker save -o a-icon-api.tar a-iconcom-api:latest
docker save -o a-icon-web.tar a-iconcom-web:latest
Write-Host "[OK] Images saved" -ForegroundColor Green

# Step 2: Transfer tar files to droplet
Write-Host "`n[2/6] Transferring images to droplet..." -ForegroundColor Yellow
scp -i $SSH_KEY -o StrictHostKeyChecking=no a-icon-api.tar ${SSH_USER}@${DROPLET_IP}:/tmp/
scp -i $SSH_KEY -o StrictHostKeyChecking=no a-icon-web.tar ${SSH_USER}@${DROPLET_IP}:/tmp/
Write-Host "[OK] Images transferred" -ForegroundColor Green

# Step 3: Load images on droplet
Write-Host "`n[3/6] Loading images on droplet..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker load -i /tmp/a-icon-api.tar && docker load -i /tmp/a-icon-web.tar"
Write-Host "[OK] Images loaded" -ForegroundColor Green

# Step 4: Stop and remove old containers
Write-Host "`n[4/6] Stopping old containers..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker stop a-icon-hello a-icon-api a-icon-web 2>/dev/null; true"
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker rm a-icon-hello a-icon-api a-icon-web 2>/dev/null; true"
Write-Host "[OK] Old containers removed" -ForegroundColor Green

# Step 5: Create data directory and network
Write-Host "`n[5/6] Setting up environment..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "mkdir -p /opt/a-icon/data && (docker network create a-icon-network 2>/dev/null; true)"
Write-Host "[OK] Environment ready" -ForegroundColor Green

# Step 6: Run containers
Write-Host "`n[6/6] Starting containers..." -ForegroundColor Yellow

# Start API container
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker run -d --name a-icon-api --restart unless-stopped --network a-icon-network -p 3000:3000 -v /opt/a-icon/data:/usr/src/app/data -e NODE_ENV=production -e PORT=3000 -e DB_PATH=/usr/src/app/data/a-icon.db -e STORAGE_ROOT=/usr/src/app/data/storage a-iconcom-api:latest"

# Start Web container
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker run -d --name a-icon-web --restart unless-stopped --network a-icon-network -p 80:4000 -e NODE_ENV=production -e PORT=4000 a-iconcom-web:latest"

Write-Host "[OK] Containers started" -ForegroundColor Green

# Step 7: Verify deployment
Write-Host "`n[7/7] Verifying deployment..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker ps"

Write-Host "`n=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Site should be available at: http://a-icon.com" -ForegroundColor Green
Write-Host "API should be available at: http://a-icon.com:3000" -ForegroundColor Green

# Cleanup local tar files
Write-Host "`nCleaning up local tar files..." -ForegroundColor Yellow
Remove-Item a-icon-api.tar, a-icon-web.tar -ErrorAction SilentlyContinue
Write-Host "[OK] Cleanup complete" -ForegroundColor Green

