#!/usr/bin/env pwsh

# Configuration
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"
$SSH_USER = "ubuntu"
$DROPLET_IP = "167.71.191.234"
$DOMAIN = "a-icon.com"
$EMAIL = "senneseph@gmail.com"

Write-Host "=== Setting up Let's Encrypt SSL for $DOMAIN ===" -ForegroundColor Cyan

# Create initial Nginx configuration (HTTP only for certificate acquisition)
$nginxConfigInitial = @"
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Proxy to Angular app
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_cache_bypass `$http_upgrade;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }

    # Proxy to API
    location /api/ {
        proxy_pass http://localhost:3000/api/;
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
"@

# Create final Nginx configuration (with SSL)
$nginxConfigFinal = @"
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Redirect all other HTTP traffic to HTTPS
    location / {
        return 301 https://`$host`$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    # Proxy to Angular app
    location / {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_cache_bypass `$http_upgrade;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }

    # Proxy to API
    location /api/ {
        proxy_pass http://localhost:3000/api/;
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
"@

Write-Host "[1/6] Installing Nginx and Certbot..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} @"
sudo apt-get update
sudo apt-get install -y nginx certbot python3-certbot-nginx
sudo mkdir -p /var/www/certbot
"@

Write-Host "[2/7] Reconfiguring web container to port 8080..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} @"
docker stop a-icon-web
docker rm a-icon-web
docker run -d --name a-icon-web --restart unless-stopped --network a-icon-network -p 8080:4000 -e NODE_ENV=production -e PORT=4000 a-iconcom-web:latest
"@

Write-Host "[3/7] Creating initial Nginx configuration..." -ForegroundColor Yellow
$nginxConfigInitial | Out-File -FilePath "nginx-initial.conf" -Encoding ASCII -NoNewline
Add-Content -Path "nginx-initial.conf" -Value "`n" -NoNewline
scp -i $SSH_KEY -o StrictHostKeyChecking=no nginx-initial.conf ${SSH_USER}@${DROPLET_IP}:/tmp/
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} @"
sudo mv /tmp/nginx-initial.conf /etc/nginx/sites-available/a-icon
sudo ln -sf /etc/nginx/sites-available/a-icon /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
"@

Write-Host "[4/7] Obtaining SSL certificate..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} @"
sudo certbot certonly --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email $EMAIL
"@

Write-Host "[5/7] Creating final Nginx configuration with SSL..." -ForegroundColor Yellow
$nginxConfigFinal | Out-File -FilePath "nginx-final.conf" -Encoding ASCII -NoNewline
Add-Content -Path "nginx-final.conf" -Value "`n" -NoNewline
scp -i $SSH_KEY -o StrictHostKeyChecking=no nginx-final.conf ${SSH_USER}@${DROPLET_IP}:/tmp/
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} @"
sudo mv /tmp/nginx-final.conf /etc/nginx/sites-available/a-icon
sudo nginx -t
sudo systemctl restart nginx
"@

Write-Host "[6/7] Setting up auto-renewal..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} @"
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
"@

Write-Host "[7/7] Verifying deployment..." -ForegroundColor Yellow
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "docker ps"

Write-Host ""
Write-Host "=== SSL Setup Complete ===" -ForegroundColor Green
Write-Host "Site should now be available at: https://$DOMAIN" -ForegroundColor Green
Write-Host ""
Write-Host "Certificate will auto-renew via certbot timer" -ForegroundColor Cyan

# Cleanup
Remove-Item nginx-initial.conf -ErrorAction SilentlyContinue
Remove-Item nginx-final.conf -ErrorAction SilentlyContinue

