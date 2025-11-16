# A-Icon Deployment Guide

This guide covers deploying a-icon.com to DigitalOcean using Terraform.

## Prerequisites

1. **DigitalOcean Account** with API token
2. **Terraform** installed (v1.0+)
3. **SSH Key Pair** for server access
4. **Domain** (a-icon.com) configured in DigitalOcean

## Quick Start

### 1. Generate SSH Key (if you don't have one)

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/a-icon-deploy -C "a-icon-deployment"
```

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and add:
- Your DigitalOcean API token from `.env`
- Your SSH public key content (from `~/.ssh/a-icon-deploy.pub`)

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review the Plan

```bash
terraform plan
```

This will show you what resources will be created:
- 1 Droplet ($6/month, 1GB RAM, 1 vCPU)
- 1 SSH Key
- 1 Firewall (ports 22, 80, 443)
- 3 DNS A records (root, www, api)

### 5. Deploy Infrastructure

```bash
terraform apply
```

Type `yes` when prompted. This will:
- Create the droplet
- Configure DNS records
- Set up firewall rules
- Install Docker, Nginx, and Certbot via cloud-init

**Note:** The droplet will take 2-3 minutes to fully initialize.

### 6. Get the Droplet IP

```bash
terraform output droplet_ip
```

### 7. Deploy the Application

SSH into the droplet:

```bash
ssh -i ~/.ssh/a-icon-deploy ubuntu@$(terraform output -raw droplet_ip)
```

On the droplet, run the deployment script:

```bash
cd /opt/a-icon
curl -o deploy.sh https://raw.githubusercontent.com/Senneseph/a-icon.com/master/deploy.sh
chmod +x deploy.sh
./deploy.sh
```

The script will:
- Clone the repository
- Build Docker images
- Start the containers
- Configure SSL with Let's Encrypt
- Set up auto-renewal for SSL certificates

### 8. Verify Deployment

Visit https://a-icon.com in your browser. You should see the Angular application.

Test the API:
```bash
curl https://a-icon.com/api/health
```

## Architecture

```
Internet
   |
   v
DigitalOcean DNS (a-icon.com)
   |
   v
Droplet (Ubuntu 20.04 + Docker)
   |
   +-- Nginx (Port 80/443) + Let's Encrypt SSL
        |
        +-- /     -> Docker: a-icon-web (Angular SSR on port 4200)
        +-- /api  -> Docker: a-icon-api (NestJS on port 3000)
                        |
                        +-- SQLite Database (/opt/a-icon/data/a-icon.db)
                        +-- File Storage (/opt/a-icon/data/storage)
```

## Costs

- **Droplet**: $6/month (s-1vcpu-1gb)
- **Bandwidth**: 1TB included
- **DNS**: Free
- **SSL**: Free (Let's Encrypt)

**Total**: ~$6/month

## Maintenance

### View Logs

```bash
ssh -i ~/.ssh/a-icon-deploy ubuntu@<DROPLET_IP>
cd /opt/a-icon
docker-compose -f docker-compose.prod.yml logs -f
```

### Restart Services

```bash
docker-compose -f docker-compose.prod.yml restart
```

### Update Application

```bash
./deploy.sh
```

### SSL Certificate Renewal

Certificates auto-renew via certbot timer. Check status:

```bash
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

## Destroy Infrastructure

To tear down all resources:

```bash
cd terraform
terraform destroy
```

Type `yes` when prompted. This will delete:
- The droplet
- DNS records
- Firewall rules
- SSH key

**Warning:** This is irreversible and will delete all data on the droplet.

## Troubleshooting

### DNS not resolving

Wait 5-10 minutes for DNS propagation. Check with:

```bash
dig a-icon.com
nslookup a-icon.com
```

### Containers not starting

Check logs:

```bash
docker-compose -f docker-compose.prod.yml logs
```

### SSL certificate failed

Ensure DNS is pointing to the droplet before running certbot:

```bash
sudo certbot --nginx -d a-icon.com -d www.a-icon.com
```

### Can't SSH into droplet

Verify your SSH key is correct:

```bash
ssh -i ~/.ssh/a-icon-deploy ubuntu@<DROPLET_IP> -v
```

## Security Notes

- Firewall only allows ports 22 (SSH), 80 (HTTP), 443 (HTTPS)
- Docker containers run as non-root users
- SSL/TLS enforced via Let's Encrypt
- Regular security updates via unattended-upgrades (configured in cloud-init)

