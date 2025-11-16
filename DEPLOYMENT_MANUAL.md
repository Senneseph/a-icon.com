# Manual Deployment Instructions

Since automated SSH deployment is having issues, here's how to deploy manually via the DigitalOcean web console.

## Droplet Information

- **IP Address**: 142.93.178.220
- **Droplet ID**: 530298582
- **Domain**: a-icon.com

## Steps

### 1. Access the Droplet Console

1. Go to https://cloud.digitalocean.com/droplets/530298582
2. Click "Access" → "Launch Droplet Console"
3. Log in as `root` (no password needed in console)

### 2. Set Up SSH Key Manually

In the console, run:

```bash
# Switch to ubuntu user
su - ubuntu

# Create .ssh directory if it doesn't exist
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Add your SSH public key
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA52pME/eI6tOn6JN+ZgP4suUu8mgcxUEVnN0yy6WaUp a-icon-deployment" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

# Exit back to root
exit
```

### 3. Deploy the Application

Still in the console:

```bash
# Switch to ubuntu user
su - ubuntu

# Navigate to deployment directory
cd /opt/a-icon
sudo chown -R ubuntu:ubuntu /opt/a-icon

# Clone the repository
git clone https://github.com/Senneseph/a-icon.com.git .

# Build and start Docker containers
docker-compose -f docker-compose.prod.yml build
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to start
sleep 15

# Check status
docker-compose -f docker-compose.prod.yml ps
```

### 4. Configure SSL

```bash
# Install SSL certificate
sudo certbot --nginx -d a-icon.com -d www.a-icon.com --non-interactive --agree-tos --email admin@a-icon.com --redirect

# Enable auto-renewal
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
```

### 5. Verify Deployment

Visit https://a-icon.com in your browser.

Test the API:
```bash
curl https://a-icon.com/api/health
```

## Alternative: Fix SSH from Windows

If you want to fix SSH access from your Windows machine:

```powershell
# Test SSH connection
ssh -i $env:USERPROFILE\.ssh\a-icon-deploy ubuntu@142.93.178.220

# If it works after step 2 above, you can use the automated script:
.\deploy-remote.ps1
```

## Troubleshooting

### Check cloud-init status

```bash
cloud-init status
```

### View cloud-init logs

```bash
sudo cat /var/log/cloud-init-output.log
```

### Check Docker status

```bash
docker ps
docker-compose -f /opt/a-icon/docker-compose.prod.yml logs
```

### Check Nginx status

```bash
sudo systemctl status nginx
sudo nginx -t
```

### View application logs

```bash
cd /opt/a-icon
docker-compose -f docker-compose.prod.yml logs -f api
docker-compose -f docker-compose.prod.yml logs -f web
```

