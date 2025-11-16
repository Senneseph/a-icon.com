#!/bin/bash

set -e

echo "=== A-Icon Deployment Script ==="
echo ""

# Configuration
REPO_URL="https://github.com/Senneseph/a-icon.com.git"
DEPLOY_DIR="/opt/a-icon"
DOMAIN="a-icon.com"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if running as root or with sudo
if [ "$EUID" -eq 0 ]; then 
    echo -e "${YELLOW}Warning: Running as root. Switching to ubuntu user for deployment.${NC}"
    SUDO_CMD=""
else
    SUDO_CMD="sudo"
fi

# Function to print status
print_status() {
    echo -e "${GREEN}==>${NC} $1"
}

print_error() {
    echo -e "${RED}ERROR:${NC} $1"
}

# Navigate to deployment directory
cd "$DEPLOY_DIR" || {
    print_error "Deployment directory $DEPLOY_DIR does not exist"
    exit 1
}

# Pull latest code or clone if not exists
if [ -d ".git" ]; then
    print_status "Pulling latest code from repository..."
    git pull origin master
else
    print_status "Cloning repository..."
    git clone "$REPO_URL" .
fi

# Stop existing containers
print_status "Stopping existing containers..."
docker-compose -f docker-compose.prod.yml down || true

# Build images
print_status "Building Docker images..."
docker-compose -f docker-compose.prod.yml build --no-cache

# Start containers
print_status "Starting containers..."
docker-compose -f docker-compose.prod.yml up -d

# Wait for services to be healthy
print_status "Waiting for services to start..."
sleep 10

# Check if containers are running
if docker ps | grep -q "a-icon-api" && docker ps | grep -q "a-icon-web"; then
    print_status "Containers are running successfully!"
else
    print_error "Containers failed to start. Check logs with: docker-compose -f docker-compose.prod.yml logs"
    exit 1
fi

# Configure SSL if not already configured
if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    print_status "Configuring SSL certificate with Let's Encrypt..."
    $SUDO_CMD certbot --nginx -d "$DOMAIN" -d "www.$DOMAIN" --non-interactive --agree-tos --email admin@$DOMAIN --redirect
    
    # Set up auto-renewal
    print_status "Setting up SSL auto-renewal..."
    $SUDO_CMD systemctl enable certbot.timer
    $SUDO_CMD systemctl start certbot.timer
else
    print_status "SSL certificate already configured"
fi

# Show container status
print_status "Container status:"
docker-compose -f docker-compose.prod.yml ps

echo ""
print_status "Deployment complete!"
echo -e "${GREEN}Application is now running at:${NC}"
echo -e "  - https://$DOMAIN"
echo -e "  - https://www.$DOMAIN"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo -e "  View logs:    docker-compose -f docker-compose.prod.yml logs -f"
echo -e "  Restart:      docker-compose -f docker-compose.prod.yml restart"
echo -e "  Stop:         docker-compose -f docker-compose.prod.yml down"
echo -e "  Rebuild:      docker-compose -f docker-compose.prod.yml up -d --build"

