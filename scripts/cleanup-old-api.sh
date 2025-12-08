#!/bin/bash

# Cleanup old NestJS API from droplet
# This script removes the a-icon-api Docker container and image

set -e

echo "=== Cleaning up old NestJS API ==="
echo ""

# Check current containers
echo "Current Docker containers:"
docker ps -a --filter "name=a-icon-api" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo ""

# Stop the container if running
echo "Stopping a-icon-api container..."
docker stop a-icon-api 2>/dev/null || echo "Container not running or already stopped"
echo ""

# Remove the container
echo "Removing a-icon-api container..."
docker rm a-icon-api 2>/dev/null || echo "Container not found or already removed"
echo ""

# Check for the image
echo "Checking for a-icon-api images..."
docker images --filter "reference=*a-icon*api*" --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}"
echo ""

# Remove the image
echo "Removing a-icon-api image..."
docker rmi a-icon-api 2>/dev/null || docker rmi a-icon_api 2>/dev/null || echo "Image not found or already removed"
echo ""

# Also check for any images from the build
echo "Removing any related images..."
docker images | grep "a-icon" | grep "api" | awk '{print $3}' | xargs -r docker rmi -f 2>/dev/null || echo "No additional images found"
echo ""

# Clean up unused volumes (optional - be careful!)
echo "Listing Docker volumes:"
docker volume ls | grep "a-icon" || echo "No a-icon volumes found"
echo ""

echo "=== Cleanup Summary ==="
echo ""
echo "Remaining containers:"
docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}"
echo ""

echo "Remaining images:"
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep -E "(REPOSITORY|a-icon)" || echo "No a-icon images remaining"
echo ""

echo "✓ Cleanup complete!"
echo ""
echo "Note: The a-icon-web container is still running (as expected)"
echo "Note: The api-data volume is preserved (contains database and storage)"

