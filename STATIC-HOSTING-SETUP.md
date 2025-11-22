# Static Hosting Setup Guide

## Prerequisites Setup

Before you can use the static hosting scripts, you need to set up DigitalOcean CLI authentication.

### Step 1: Verify doctl Installation

```powershell
doctl version
```

If not installed, download from: https://docs.digitalocean.com/reference/doctl/how-to/install/

### Step 2: Get Your DigitalOcean API Token

1. Log in to DigitalOcean: https://cloud.digitalocean.com/
2. Go to **API** → **Tokens/Keys**
3. Click **Generate New Token**
4. Name it "Static Hosting CLI"
5. Check **Write** scope
6. Copy the token (you'll only see it once!)

### Step 3: Authenticate doctl

**Option A: Interactive (Recommended)**

```powershell
doctl auth init
```

Paste your token when prompted.

**Option B: Using Environment Variable**

```powershell
# Set the token (replace with your actual token)
$env:DO_TOKEN = "dop_v1_xxxxxxxxxxxxxxxxxxxxxxxxxxxxx"

# Initialize doctl
doctl auth init --access-token $env:DO_TOKEN
```

### Step 4: Verify Authentication

```powershell
doctl account get
```

You should see your account information.

### Step 5: Verify Domain Access

```powershell
doctl compute domain list
```

You should see your domains (a-icon.com, iffuso.com, etc.)

## Quick Start Examples

### Example 1: Add iffuso.com

```powershell
# Create a simple test site
mkdir -p test-site
@"
<!DOCTYPE html>
<html>
<head>
    <title>Iffuso.com</title>
    <style>
        body { font-family: Arial; max-width: 800px; margin: 50px auto; padding: 20px; }
        h1 { color: #667eea; }
    </style>
</head>
<body>
    <h1>Welcome to Iffuso.com</h1>
    <p>This site is hosted on the a-icon.com droplet.</p>
    <p>Powered by Nginx + Let's Encrypt SSL</p>
</body>
</html>
"@ | Out-File -FilePath test-site/index.html -Encoding UTF8

# Deploy it
.\add-static-site.ps1 -Domain "iffuso.com" -SourcePath "./test-site"
```

Wait 2-3 minutes for DNS propagation and SSL certificate, then visit: **https://iffuso.com**

### Example 2: Add angular-press.iffuso.com

```powershell
# Assuming you have an Angular app built in ./dist/angular-press
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "angular-press" -SourcePath "./dist/angular-press"
```

Visit: **https://angular-press.iffuso.com**

### Example 3: Add Multiple Subdomains

```powershell
# Main site
.\add-static-site.ps1 -Domain "iffuso.com" -SourcePath "./main-site"

# WWW (same content as main)
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "www" -SourcePath "./main-site"

# Blog
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "blog" -SourcePath "./blog-dist"

# Docs
.\add-static-site.ps1 -Domain "iffuso.com" -Subdomain "docs" -SourcePath "./docs-dist"
```

## Common Workflows

### Update an Existing Site

```powershell
# Option 1: Use SCP directly
scp -i ~/.ssh/a-icon-deploy -r ./dist/* ubuntu@167.71.191.234:/var/www/iffuso.com/

# Option 2: Re-run the script (skips DNS/SSL if already configured)
.\add-static-site.ps1 -Domain "iffuso.com" -SourcePath "./dist" -SkipDNS
```

### List All Sites

```powershell
.\list-static-sites.ps1
```

### Remove a Site

```powershell
# Remove everything
.\remove-static-site.ps1 -Domain "iffuso.com"

# Remove subdomain
.\remove-static-site.ps1 -Domain "iffuso.com" -Subdomain "blog"
```

### Manual File Management

```powershell
# SSH into droplet
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234

# Navigate to site
cd /var/www/iffuso.com

# Edit files
nano index.html

# Check Nginx config
cat /etc/nginx/sites-available/iffuso.com

# Reload Nginx after manual config changes
sudo nginx -t
sudo systemctl reload nginx
```

## Troubleshooting

### "doctl is not authenticated"

Run:
```powershell
doctl auth init
```

### "Domain not found in DigitalOcean"

Make sure the domain is added to your DigitalOcean account:
1. Go to https://cloud.digitalocean.com/networking/domains
2. Click **Add Domain**
3. Enter your domain name
4. Click **Add Domain**

Or use the script with `-SkipDNS` and configure DNS manually.

### "SSH connection failed"

Verify SSH key exists:
```powershell
Test-Path ~/.ssh/a-icon-deploy
```

If not, the key may be in a different location. Check `droplet-info.json` for the correct droplet IP.

### Site not loading after 5 minutes

1. Check DNS propagation:
   ```powershell
   nslookup iffuso.com
   ```

2. Check Nginx status:
   ```powershell
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo systemctl status nginx'
   ```

3. Check Nginx logs:
   ```powershell
   ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo tail -50 /var/log/nginx/error.log'
   ```

### SSL certificate failed

Let's Encrypt has rate limits. If you hit them, wait 1 hour or use `-SkipSSL` for testing:

```powershell
.\add-static-site.ps1 -Domain "test.iffuso.com" -SkipSSL
```

Then add SSL later manually:
```bash
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234
sudo certbot --nginx -d test.iffuso.com
```

## Advanced Usage

### Custom Nginx Configuration

After running the script, you can manually edit the Nginx config:

```bash
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234
sudo nano /etc/nginx/sites-available/iffuso.com
sudo nginx -t
sudo systemctl reload nginx
```

### Add Custom Headers

Edit the Nginx config and add:

```nginx
add_header X-Custom-Header "value" always;
```

### Add Basic Authentication

```bash
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234
sudo apt-get install apache2-utils
sudo htpasswd -c /etc/nginx/.htpasswd username
```

Then edit Nginx config:

```nginx
location / {
    auth_basic "Restricted";
    auth_basic_user_file /etc/nginx/.htpasswd;
    try_files $uri $uri/ /index.html;
}
```

### Add Reverse Proxy

You can mix static hosting with reverse proxying:

```nginx
location /api {
    proxy_pass http://localhost:8080;
}

location / {
    try_files $uri $uri/ /index.html;
}
```

## Best Practices

1. **Always test locally first** before deploying
2. **Use version control** for your static sites
3. **Minify assets** before uploading (CSS, JS, images)
4. **Use meaningful subdomain names** (blog, docs, app, etc.)
5. **Monitor disk space** - the droplet has 25GB total
6. **Keep backups** of important sites
7. **Use CDN** for high-traffic sites (CloudFlare, etc.)

## Monitoring

### Check Disk Space

```powershell
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'df -h'
```

### Check Site Size

```powershell
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'du -sh /var/www/*'
```

### View Access Logs

```powershell
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo tail -f /var/log/nginx/access.log'
```

### Check SSL Certificate Expiry

```powershell
ssh -i ~/.ssh/a-icon-deploy ubuntu@167.71.191.234 'sudo certbot certificates'
```

## Cost Breakdown

- **Droplet**: $6/month (already running)
- **Additional domains**: $0
- **SSL certificates**: $0 (Let's Encrypt)
- **Bandwidth**: Included (1TB/month)

**Total additional cost: $0** 🎉

## Next Steps

1. ✅ Set up doctl authentication (see above)
2. ✅ Verify domain is in DigitalOcean
3. ✅ Run `.\add-static-site.ps1 -Domain "your-domain.com"`
4. ✅ Wait 2-3 minutes for DNS + SSL
5. ✅ Visit https://your-domain.com

Happy hosting! 🚀

