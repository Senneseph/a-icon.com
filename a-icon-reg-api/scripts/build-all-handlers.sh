#!/bin/bash

# Build all Rust Edge Gateway handlers
# This script builds the shared library and all 11 handlers

set -e  # Exit on error

echo "=== Building Rust Edge Gateway Handlers ==="
echo ""

# Build shared library first
echo "[1/12] Building shared library..."
cd shared
cargo build --release
cd ..
echo "✓ Shared library built"
echo ""

# List of all handlers
HANDLERS=(
    "health"
    "directory"
    "favicons-upload"
    "favicons-canvas"
    "favicons-get"
    "admin-login"
    "admin-logout"
    "admin-verify"
    "admin-delete"
    "storage-source"
    "storage-asset"
)

# Build each handler
COUNTER=2
for handler in "${HANDLERS[@]}"; do
    echo "[$COUNTER/12] Building $handler..."
    cd "handlers/$handler"
    
    # Downgrade AWS SDK versions for Rust 1.86.0 compatibility
    cargo update aws-sdk-s3 --precise 1.50.0 2>/dev/null || true
    cargo update aws-config --precise 1.5.0 2>/dev/null || true
    cargo update aws-sdk-sso --precise 1.40.0 2>/dev/null || true
    cargo update aws-sdk-ssooidc --precise 1.40.0 2>/dev/null || true
    cargo update aws-sdk-sts --precise 1.40.0 2>/dev/null || true
    
    # Build the handler
    cargo build --release
    
    cd ../..
    echo "✓ $handler built"
    echo ""
    COUNTER=$((COUNTER + 1))
done

echo "=== Build Complete ==="
echo ""
echo "Binaries location:"
echo "  Shared: target/release/liba_icon_shared.rlib"
for handler in "${HANDLERS[@]}"; do
    echo "  $handler: handlers/$handler/target/release/$handler"
done
echo ""
echo "Next steps:"
echo "1. Upload binaries to REG admin UI at https://rust-edge-gateway.iffuso.com/admin/"
echo "2. Configure routes according to openapi.yaml"
echo "3. Test endpoints"

