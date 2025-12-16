#!/bin/bash
set -e

# Configuration
REG_URL="${REG_URL:-https://rust-edge-gateway.iffuso.com}"
DOMAIN="${DOMAIN:-a-icon.com}"
COMPILE="${COMPILE:-true}"
START="${START:-true}"
BUNDLE_NAME="a-icon-api-bundle.zip"

echo "=== A-Icon API Deployment to Rust Edge Gateway ==="
echo "REG URL: $REG_URL"
echo "Domain: $DOMAIN"
echo "Compile: $COMPILE"
echo "Start: $START"
echo ""

# Navigate to the a-icon-reg-api directory
cd "$(dirname "$0")/.."

# Create temporary directory for bundle
TEMP_DIR=$(mktemp -d)
echo "Creating bundle in: $TEMP_DIR"

# Copy openapi.yaml
echo "Copying openapi.yaml..."
cp openapi.yaml "$TEMP_DIR/"

# Create handlers directory
mkdir -p "$TEMP_DIR/handlers"

# Map handler directories to operationIds (from openapi.yaml)
declare -A HANDLER_MAP=(
    ["health"]="getHealth"
    ["directory"]="listDirectory"
    ["favicons-upload"]="uploadFavicon"
    ["favicons-canvas"]="createFromCanvas"
    ["favicons-get"]="getFavicon"
    ["admin-login"]="adminLogin"
    ["admin-logout"]="adminLogout"
    ["admin-verify"]="adminVerify"
    ["admin-delete"]="deleteFavicons"
    ["storage-source"]="getSourceImage"
    ["storage-asset"]="getFile"
)

# Copy handler source files
echo "Copying handler source files..."
for handler_dir in "${!HANDLER_MAP[@]}"; do
    operation_id="${HANDLER_MAP[$handler_dir]}"
    src_file="handlers/$handler_dir/src/main.rs"
    
    if [ -f "$src_file" ]; then
        dest_file="$TEMP_DIR/handlers/${operation_id}.rs"
        echo "  $handler_dir -> ${operation_id}.rs"
        cp "$src_file" "$dest_file"
    else
        echo "  WARNING: $src_file not found, skipping"
    fi
done

# Copy shared library
echo "Copying shared library..."
mkdir -p "$TEMP_DIR/shared/src"
cp -r shared/src/* "$TEMP_DIR/shared/src/"
cp shared/Cargo.toml "$TEMP_DIR/shared/"

# Create Cargo.toml for each handler
echo "Creating Cargo.toml files for handlers..."
for handler_dir in "${!HANDLER_MAP[@]}"; do
    operation_id="${HANDLER_MAP[$handler_dir]}"
    cargo_toml="handlers/$handler_dir/Cargo.toml"
    
    if [ -f "$cargo_toml" ]; then
        dest_cargo="$TEMP_DIR/handlers/${operation_id}.Cargo.toml"
        cp "$cargo_toml" "$dest_cargo"
    fi
done

# Create the ZIP bundle
echo "Creating ZIP bundle..."
cd "$TEMP_DIR"
zip -r "$BUNDLE_NAME" openapi.yaml handlers/ shared/
cd -

# Move bundle to current directory
mv "$TEMP_DIR/$BUNDLE_NAME" .

echo ""
echo "Bundle created: $BUNDLE_NAME"
echo "Bundle size: $(du -h $BUNDLE_NAME | cut -f1)"
echo ""

# Upload to Rust Edge Gateway
echo "Uploading to Rust Edge Gateway..."
UPLOAD_URL="$REG_URL/api/import/bundle?domain=$DOMAIN&compile=$COMPILE&start=$START"

echo "Upload URL: $UPLOAD_URL"
echo ""

curl -X POST "$UPLOAD_URL" \
    -F "bundle=@$BUNDLE_NAME" \
    -v

echo ""
echo ""
echo "=== Deployment Complete ==="
echo "Bundle: $BUNDLE_NAME"
echo "Domain: $DOMAIN"
echo ""
echo "Check the gateway logs for compilation status."
echo "Access your API at: https://$DOMAIN/api/"
echo ""

# Cleanup
rm -rf "$TEMP_DIR"
echo "Cleaned up temporary files."

