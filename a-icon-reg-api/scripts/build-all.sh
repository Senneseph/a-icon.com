#!/bin/bash
# Build all Rust Edge Gateway handlers for A-Icon API

set -e

echo "=== Building A-Icon Rust Edge Gateway Handlers ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Build shared library first
echo -e "${BLUE}[1/1] Building shared library...${NC}"
cd shared
cargo build --release
cd ..
echo -e "${GREEN}✓ Shared library built${NC}"
echo ""

# Array of handlers to build
handlers=(
    "health"
    "favicons-upload"
    "favicons-canvas"
    "favicons-get"
    "directory"
    "admin-login"
    "admin-logout"
    "admin-verify"
    "admin-delete"
    "storage-source"
    "storage-asset"
)

# Build each handler
total=${#handlers[@]}
current=0

for handler in "${handlers[@]}"; do
    current=$((current + 1))
    echo -e "${BLUE}[${current}/${total}] Building ${handler} handler...${NC}"
    
    cd "handlers/${handler}"
    cargo build --release
    cd - > /dev/null
    
    echo -e "${GREEN}✓ ${handler} handler built${NC}"
    echo ""
done

echo -e "${GREEN}=== All handlers built successfully! ===${NC}"
echo ""
echo "Binaries are located at:"
for handler in "${handlers[@]}"; do
    binary_name=$(basename "${handler}")
    echo "  - handlers/${handler}/target/release/${binary_name}"
done
echo ""
echo "Next steps:"
echo "  1. Access the Rust Edge Gateway admin UI"
echo "  2. Upload each binary"
echo "  3. Configure routes according to openapi.yaml"
echo "  4. Test endpoints"

