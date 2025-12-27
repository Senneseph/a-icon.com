#!/bin/bash
# Build handlers for Linux x86_64 using Docker
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "=== Building A-Icon API Handlers for Linux x86_64 ==="
echo "Project directory: $PROJECT_DIR"
echo ""

cd "$PROJECT_DIR"

# Build the Docker image
echo "Building Docker image..."
docker build -f Dockerfile.build -t a-icon-handlers-build .

# Create output directory
mkdir -p dist

# Run the build container and copy out the binaries
echo "Extracting built binaries..."
docker run --rm -v "$PROJECT_DIR/dist:/output" a-icon-handlers-build sh -c "cp -r /dist/* /output/"

echo ""
echo "=== Build Complete ==="
echo "Binaries available in: $PROJECT_DIR/dist/"
ls -la "$PROJECT_DIR/dist/"
echo ""
echo "Handler binaries:"
ls -la "$PROJECT_DIR/dist/handlers/" 2>/dev/null || echo "No handlers directory found"

