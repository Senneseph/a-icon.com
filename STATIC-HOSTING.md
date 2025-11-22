# Static Site Hosting on a-icon.com Droplet

This guide explains how to host multiple static websites on the a-icon.com DigitalOcean droplet using Nginx.

## Overview

The a-icon.com droplet can host multiple static websites alongside the main a-icon.com application. Each site gets:

- **Automatic DNS configuration** via DigitalOcean API (using `doctl`)
- **Nginx web server** configuration with optimized settings
- **Free SSL certificates** from Let's Encrypt
- **Automatic HTTPS redirect**
- **Gzip compression** for faster loading
- **Cache headers** for static assets
- **SPA support** (Single Page Application routing)

## Prerequisites

1. **DigitalOcean CLI (`doctl`)** installed and authenticated
2. **Domain registered** in DigitalOcean (or DNS pointing to droplet)
3. **SSH access** to the droplet (`~/.ssh/a-icon-deploy` key)
4. **droplet-info.json** file in the project root

## Quick Start

### Add a New Static Site

```powershell
# Basic usage - domain only
.\add-static-site.ps1 -Domain "iffuso.com"

# With subdomain
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "www"

# With subdomain and source files
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "angular-press" -SourcePath "./dist/angular-press"

# Skip DNS (if already configured)
.\add-static-site.ps1 -Domain "iffuso.com" -SkipDNS

# Skip SSL (HTTP only)
.\add-static-site.ps1 -Domain "iffuso.com" -SkipSSL
```

### Upload Files to Existing Site

```powershell
# Using SCP
scp -i ~/.ssh/a-icon-deploy -r ./dist/* ubuntu@167.71.191.234:/var/www/iffuso.com/

# Or using the add-static-site script again with -SourcePath
.\add-static-site.ps1 -Domain "iffuso.com" -SourcePath "./dist" -SkipDNS
```

### List All Static Sites

```powershell
.\list-static-sites.ps1
```

### Remove a Static Site

```powershell
# Remove everything (DNS, files, Nginx config, SSL)
.\remove-static-site.ps1 -Domain "iffuso.com"

# Remove but keep DNS record
.\remove-static-site.ps1 -Domain "iffuso.com" -KeepDNS

# Remove but keep files on server
.\remove-static-site.ps1 -Domain "iffuso.com" -KeepFiles

# Remove subdomain
.\remove-static-site.ps1 -Domain "iffuso.com" -Subdomain "www"
```

## What the Script Does

### 1. DNS Configuration (via doctl)

Creates an A record pointing your domain to the droplet IP:

```
iffuso.com          A    167.71.191.234
angular-press       A    167.71.191.234  (for subdomain)
```

### 2. Directory Structure

Creates a directory on the droplet:

```
/var/www/iffuso.com/
├── index.html
├── assets/
├── css/
└── js/
```

### 3. Nginx Configuration

Creates an optimized Nginx configuration at `/etc/nginx/sites-available/iffuso.com`:

```nginx
server {
    listen 80;
    server_name iffuso.com;
    
    root /var/www/iffuso.com;
    index index.html index.htm;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Gzip compression
    gzip on;
    gzip_types text/plain text/css application/json application/javascript;
    
    # Cache static assets for 1 year
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # SPA fallback - try files, then index.html
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

### 4. SSL Certificate

Automatically obtains and configures a free SSL certificate from Let's Encrypt:

```bash
sudo certbot --nginx -d iffuso.com --non-interactive --agree-tos --redirect
```

This:
- Obtains the certificate
- Updates Nginx config to use HTTPS
- Adds automatic HTTP → HTTPS redirect
- Sets up auto-renewal (certificates renew every 90 days)

## Examples

### Example 1: Host iffuso.com

```powershell
.\add-static-site.ps1 -Domain "iffuso.com" -SourcePath "./iffuso-site/dist"
```

Result:
- DNS: `iffuso.com` → `167.71.191.234`
- Files: `/var/www/iffuso.com/`
- URL: `https://iffuso.com`

### Example 2: Host angular-press.iffuso.com

```powershell
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "angular-press" -SourcePath "./angular-press/dist"
```

Result:
- DNS: `angular-press.iffuso.com` → `167.71.191.234`
- Files: `/var/www/angular-press.iffuso.com/`
- URL: `https://angular-press.iffuso.com`

### Example 3: Multiple Sites on Same Domain

```powershell
# Root domain
.\add-static-site.ps1 -Domain "iffuso.com" -SourcePath "./main-site"

# WWW subdomain
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "www" -SourcePath "./main-site"

# Blog subdomain
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "blog" -SourcePath "./blog-site"

# App subdomain
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "app" -SourcePath "./app-dist"
```

## Manual File Management

### SSH into Droplet

```powershell
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234
```

### Navigate to Site Directory

```bash
cd /var/www/iffuso.com
ls -la
```

### Edit Files Directly

```bash
nano /var/www/iffuso.com/index.html
```

### Check Nginx Configuration

```bash
cat /etc/nginx/sites-available/iffuso.com
sudo nginx -t  # Test configuration
sudo systemctl reload nginx  # Reload after changes
```

### View Nginx Logs

```bash
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Check SSL Certificate

```bash
sudo certbot certificates
sudo ls -la /etc/letsencrypt/live/iffuso.com/
```

## Troubleshooting

### DNS Not Resolving

Wait 5-10 minutes for DNS propagation, then check:

```powershell
nslookup iffuso.com
```

### Site Not Loading

1. Check Nginx is running:
   ```bash
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo systemctl status nginx'
   ```

2. Check Nginx configuration:
   ```bash
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo nginx -t'
   ```

3. Check Nginx logs:
   ```bash
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo tail -50 /var/log/nginx/error.log'
   ```

### SSL Certificate Issues

1. Check certificate status:
   ```bash
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo certbot certificates'
   ```

2. Manually renew:
   ```bash
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo certbot renew --force-renewal'
   ```

### Files Not Updating

Clear browser cache or use incognito mode. Static assets are cached for 1 year.

## Architecture

```
Internet
   |
   v
DigitalOcean DNS
   |
   v
Droplet (167.71.191.234)
   |
   +-- Nginx (Port 80/443)
        |
        +-- a-icon.com              -> Docker (port 4200)
        +-- api.a-icon.com          -> Docker (port 3000)
        +-- iffuso.com              -> /var/www/iffuso.com
        +-- angular-press.iffuso.com -> /var/www/angular-press.iffuso.com
        +-- [any other domain]      -> /var/www/[domain]
```

## Cost

- **Droplet**: $6/month (already running for a-icon.com)
- **Additional domains**: $0 (no extra cost)
- **SSL certificates**: $0 (Let's Encrypt is free)
- **Bandwidth**: Included in droplet cost

## Limits

- **Disk space**: 25GB total (shared with a-icon.com)
- **RAM**: 1GB (shared with a-icon.com)
- **Bandwidth**: 1TB/month
- **Domains**: Unlimited (limited only by disk space)

## Security

- All sites automatically get HTTPS via Let's Encrypt
- Security headers enabled (X-Frame-Options, X-Content-Type-Options, X-XSS-Protection)
- Hidden files (`.git`, `.env`, etc.) are blocked by Nginx
- Firewall allows only ports 22, 80, 443

## Next Steps

1. **Add your first site**: `.\add-static-site.ps1 -Domain "iffuso.com"`
2. **Upload your files**: `scp -i ~/.ssh/a-icon-deploy -r ./dist/* ubuntu@167.71.191.234:/var/www/iffuso.com/`
3. **Visit your site**: `https://iffuso.com`

For questions or issues, check the Nginx logs or contact the system administrator.

