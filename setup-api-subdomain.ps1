# Setup api.a-icon.com subdomain with DNS and SSL
$ErrorActionPreference = "Stop"

# Get DigitalOcean token from environment variable
$DO_TOKEN = $env:DO_TOKEN
if (-not $DO_TOKEN) {
    Write-Host "ERROR: DO_TOKEN environment variable not set" -ForegroundColor Red
    Write-Host "Set it with: `$env:DO_TOKEN = 'your_token_here'" -ForegroundColor Yellow
    exit 1
}

$DOMAIN = "a-icon.com"
$API_SUBDOMAIN = "api"
$DROPLET_IP = "167.71.191.234"
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"
$SSH_USER = "ubuntu"

Write-Host "[1/4] Creating DNS A record for api.a-icon.com..."

# Create DNS A record for api subdomain
$dnsRecord = @{
    type = "A"
    name = $API_SUBDOMAIN
    data = $DROPLET_IP
    ttl = 3600
} | ConvertTo-Json

$headers = @{
    Authorization = "Bearer $DO_TOKEN"
    "Content-Type" = "application/json"
}

try {
    $response = Invoke-RestMethod -Uri "https://api.digitalocean.com/v2/domains/$DOMAIN/records" `
        -Method Post `
        -Headers $headers `
        -Body $dnsRecord
    Write-Host "[OK] DNS record created: api.$DOMAIN -> $DROPLET_IP"
} catch {
    if ($_.Exception.Response.StatusCode -eq 422) {
        Write-Host "[OK] DNS record already exists"
    } else {
        Write-Host "[ERROR] Failed to create DNS record: $_"
        throw
    }
}

Write-Host "[2/4] Waiting for DNS propagation (30 seconds)..."
Start-Sleep -Seconds 30

Write-Host "[3/4] Configuring Nginx for api subdomain..."

# Nginx configuration for api subdomain
$nginxApiConfig = @"
server {
    listen 80;
    server_name api.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://`$host`$request_uri;
    }
}

server {
    listen 443 ssl http2;
    server_name api.$DOMAIN;

    ssl_certificate /etc/letsencrypt/live/api.$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/api.$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers on;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';

    # CORS headers
    add_header 'Access-Control-Allow-Origin' 'https://$DOMAIN' always;
    add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
    add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
    add_header 'Access-Control-Allow-Credentials' 'true' always;

    # Handle preflight requests
    if (`$request_method = 'OPTIONS') {
        add_header 'Access-Control-Allow-Origin' 'https://$DOMAIN' always;
        add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS' always;
        add_header 'Access-Control-Allow-Headers' 'Content-Type, Authorization' always;
        add_header 'Access-Control-Max-Age' 1728000;
        add_header 'Content-Type' 'text/plain charset=UTF-8';
        add_header 'Content-Length' 0;
        return 204;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade `$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
        proxy_cache_bypass `$http_upgrade;
    }
}
"@

# Upload initial config (without SSL)
$nginxApiConfigInitial = @"
server {
    listen 80;
    server_name api.$DOMAIN;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Host `$host;
        proxy_set_header X-Real-IP `$remote_addr;
        proxy_set_header X-Forwarded-For `$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto `$scheme;
    }
}
"@

# Write initial config
$nginxApiConfigInitial | ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "cat > /tmp/api-nginx.conf"
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "sudo mv /tmp/api-nginx.conf /etc/nginx/sites-available/api.$DOMAIN"
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "sudo ln -sf /etc/nginx/sites-available/api.$DOMAIN /etc/nginx/sites-enabled/api.$DOMAIN"
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "sudo nginx -t && sudo systemctl reload nginx"

Write-Host "[OK] Initial Nginx configuration deployed"

Write-Host "[4/4] Obtaining SSL certificate for api.$DOMAIN..."

ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "sudo certbot certonly --webroot -w /var/www/certbot -d api.$DOMAIN --non-interactive --agree-tos --email senneseph@gmail.com"

Write-Host "[OK] SSL certificate obtained"

# Upload final config with SSL
$nginxApiConfig | ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "cat > /tmp/api-nginx.conf"
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "sudo mv /tmp/api-nginx.conf /etc/nginx/sites-available/api.$DOMAIN"
ssh -i $SSH_KEY ${SSH_USER}@${DROPLET_IP} "sudo nginx -t && sudo systemctl reload nginx"

Write-Host "[OK] Final Nginx configuration with SSL deployed"

Write-Host ""
Write-Host "=========================================="
Write-Host "API Subdomain Setup Complete!"
Write-Host "=========================================="
Write-Host "API URL: https://api.$DOMAIN"
Write-Host "Test: curl https://api.$DOMAIN/api/directory"
Write-Host ""

