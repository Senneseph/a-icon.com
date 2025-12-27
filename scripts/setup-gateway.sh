#!/bin/bash
# Setup script for Rust Edge Gateway on the droplet
# This script configures the gateway via its Admin API

set -e

API_URL="${API_URL:-http://localhost:8081}"

echo "=============================================="
echo "  Rust Edge Gateway Setup"
echo "  Admin API: $API_URL"
echo "=============================================="

# Wait for gateway to be ready
echo ""
echo "1. Waiting for gateway to be ready..."
for i in {1..30}; do
    if curl -s "$API_URL/api/health" > /dev/null 2>&1; then
        echo "   Gateway is ready!"
        break
    fi
    echo "   Waiting... ($i/30)"
    sleep 2
done

# Check health
HEALTH=$(curl -s "$API_URL/api/health")
echo "   Health: $HEALTH"

# 2. Create the domain
echo ""
echo "2. Creating domain 'a-icon.com'..."
DOMAIN_RESPONSE=$(curl -s -X POST "$API_URL/api/domains" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "a-icon.com",
    "description": "A-Icon Favicon Registry"
  }')
echo "   Response: $DOMAIN_RESPONSE"

DOMAIN_ID=$(echo "$DOMAIN_RESPONSE" | jq -r '.data.id // empty')
if [ -z "$DOMAIN_ID" ]; then
    echo "   Domain may already exist, fetching..."
    DOMAIN_ID=$(curl -s "$API_URL/api/domains" | jq -r '.data[] | select(.name=="a-icon.com") | .id')
fi
echo "   Domain ID: $DOMAIN_ID"

if [ -z "$DOMAIN_ID" ]; then
    echo "ERROR: Could not create or find domain"
    exit 1
fi

# 3. Create Hello World endpoint
echo ""
echo "3. Creating Hello World endpoint..."

# Simple V1 handler using handler_loop! macro
HELLO_WORLD_CODE='use rust_edge_gateway_sdk::prelude::*;

fn handle(req: Request) -> Response {
    Response::ok(json!({
        "message": "Hello, World!",
        "path": req.path,
        "method": req.method
    }))
}

handler_loop!(handle);'

# Create the endpoint
ENDPOINT_RESPONSE=$(curl -s -X POST "$API_URL/api/endpoints" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain_id\": \"$DOMAIN_ID\",
    \"name\": \"Hello World\",
    \"path\": \"/api/hello-world\",
    \"method\": \"GET\",
    \"handler_code\": $(echo "$HELLO_WORLD_CODE" | jq -Rs .)
  }")
echo "   Response: $ENDPOINT_RESPONSE"

ENDPOINT_ID=$(echo "$ENDPOINT_RESPONSE" | jq -r '.data.id // empty')
if [ -z "$ENDPOINT_ID" ]; then
    echo "   Endpoint may already exist, fetching..."
    ENDPOINT_ID=$(curl -s "$API_URL/api/endpoints" | jq -r '.data[] | select(.path=="/api/hello-world") | .id')
fi
echo "   Endpoint ID: $ENDPOINT_ID"

if [ -z "$ENDPOINT_ID" ]; then
    echo "ERROR: Could not create Hello World endpoint"
    exit 1
fi

# 4. Compile the endpoint
echo ""
echo "4. Compiling Hello World endpoint..."
COMPILE_RESPONSE=$(curl -s -X POST "$API_URL/api/endpoints/$ENDPOINT_ID/compile")
echo "   Response: $COMPILE_RESPONSE"

# 5. Start the endpoint
echo ""
echo "5. Starting Hello World endpoint..."
START_RESPONSE=$(curl -s -X POST "$API_URL/api/endpoints/$ENDPOINT_ID/start")
echo "   Response: $START_RESPONSE"

# 6. Test the endpoint
echo ""
echo "6. Testing Hello World endpoint..."
sleep 2
TEST_RESPONSE=$(curl -s "http://localhost:8080/api/hello-world" -H "Host: a-icon.com")
echo "   Response: $TEST_RESPONSE"

echo ""
echo "=============================================="
echo "  Hello World Setup Complete!"
echo "=============================================="
echo ""
echo "Test locally: curl http://localhost:8080/api/hello-world -H 'Host: a-icon.com'"
echo "Test via domain: curl https://a-icon.com/api/hello-world"

