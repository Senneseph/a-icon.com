#!/bin/bash

# Build all handlers for Rust Edge Gateway

set -e  # Exit on error

HANDLERS_DIR="$(cd "$(dirname "$0")/../handlers" && pwd)"
BUILD_LOG="build.log"

echo "Building all handlers..."
echo "Handlers directory: $HANDLERS_DIR"
echo ""

# Clear previous log
> "$BUILD_LOG"

# List of handlers to build
HANDLERS=(
    "health"
    "directory"
    "favicons-get"
    "favicons-upload"
    "favicons-canvas"
    "admin-login"
    "admin-logout"
    "admin-verify"
    "admin-delete"
    "storage-source"
    "storage-asset"
)

BUILT=0
FAILED=0

for handler in "${HANDLERS[@]}"; do
    echo -n "Building $handler... "
    
    if [ ! -d "$HANDLERS_DIR/$handler" ]; then
        echo "SKIP (directory not found)"
        continue
    fi
    
    cd "$HANDLERS_DIR/$handler"
    
    if /usr/bin/cargo build --release >> "$HANDLERS_DIR/../$BUILD_LOG" 2>&1; then
        echo "✓ OK"
        ((BUILT++))
    else
        echo "✗ FAILED"
        ((FAILED++))
        echo "=== Error building $handler ===" >> "$HANDLERS_DIR/../$BUILD_LOG"
        tail -20 "$HANDLERS_DIR/../$BUILD_LOG" >> "$HANDLERS_DIR/../$BUILD_LOG"
    fi
done

echo ""
echo "Build Summary:"
echo "  Built: $BUILT"
echo "  Failed: $FAILED"
echo ""

if [ $FAILED -gt 0 ]; then
    echo "Check $BUILD_LOG for details"
    exit 1
fi

echo "All handlers built successfully!"
echo ""
echo "Binaries location:"
for handler in "${HANDLERS[@]}"; do
    BINARY="$HANDLERS_DIR/$handler/target/release/$handler"
    if [ -f "$BINARY" ] || [ -f "$BINARY.exe" ]; then
        echo "  ✓ $handler"
    fi
done

