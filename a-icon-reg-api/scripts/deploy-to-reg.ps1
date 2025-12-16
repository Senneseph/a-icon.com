# Configuration
$REG_URL = if ($env:REG_URL) { $env:REG_URL } else { "https://rust-edge-gateway.iffuso.com" }
$DOMAIN = if ($env:DOMAIN) { $env:DOMAIN } else { "a-icon.com" }
$COMPILE = if ($env:COMPILE) { $env:COMPILE } else { "true" }
$START = if ($env:START) { $env:START } else { "true" }
$BUNDLE_NAME = "a-icon-api-bundle.zip"

Write-Host "=== A-Icon API Deployment to Rust Edge Gateway ===" -ForegroundColor Cyan
Write-Host "REG URL: $REG_URL"
Write-Host "Domain: $DOMAIN"
Write-Host "Compile: $COMPILE"
Write-Host "Start: $START"
Write-Host ""

# Navigate to the a-icon-reg-api directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location (Join-Path $scriptDir "..")

# Create temporary directory for bundle
$TEMP_DIR = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName()))
Write-Host "Creating bundle in: $TEMP_DIR"

# Copy openapi.yaml
Write-Host "Copying openapi.yaml..."
Copy-Item "openapi.yaml" -Destination $TEMP_DIR

# Create handlers directory
$handlersDir = New-Item -ItemType Directory -Path (Join-Path $TEMP_DIR "handlers")

# Map handler directories to operationIds (from openapi.yaml)
$HANDLER_MAP = @{
    "health" = "getHealth"
    "directory" = "listDirectory"
    "favicons-upload" = "uploadFavicon"
    "favicons-canvas" = "createFromCanvas"
    "favicons-get" = "getFavicon"
    "admin-login" = "adminLogin"
    "admin-logout" = "adminLogout"
    "admin-verify" = "adminVerify"
    "admin-delete" = "deleteFavicons"
    "storage-source" = "getSourceImage"
    "storage-asset" = "getFile"
}

# Copy handler source files
Write-Host "Copying handler source files..."
foreach ($handlerDir in $HANDLER_MAP.Keys) {
    $operationId = $HANDLER_MAP[$handlerDir]
    $srcFile = "handlers\$handlerDir\src\main.rs"
    
    if (Test-Path $srcFile) {
        $destFile = Join-Path $handlersDir "$operationId.rs"
        Write-Host "  $handlerDir -> $operationId.rs"
        Copy-Item $srcFile -Destination $destFile
    } else {
        Write-Host "  WARNING: $srcFile not found, skipping" -ForegroundColor Yellow
    }
}

# Don't copy shared library or Cargo.toml files
# The gateway will handle compilation with its own SDK dependency
Write-Host "Skipping shared library (gateway will handle dependencies)..."

# Create the ZIP bundle
Write-Host "Creating ZIP bundle..."
$bundlePath = Join-Path (Get-Location) $BUNDLE_NAME
if (Test-Path $bundlePath) {
    Remove-Item $bundlePath -Force
}

Compress-Archive -Path (Join-Path $TEMP_DIR "*") -DestinationPath $bundlePath

Write-Host ""
Write-Host "Bundle created: $BUNDLE_NAME" -ForegroundColor Green
Write-Host "Bundle size: $((Get-Item $bundlePath).Length / 1KB) KB"
Write-Host ""

# Upload to Rust Edge Gateway
Write-Host "Uploading to Rust Edge Gateway..." -ForegroundColor Cyan
$UPLOAD_URL = "$REG_URL/api/import/bundle?domain=$DOMAIN&compile=$COMPILE&start=$START"

Write-Host "Upload URL: $UPLOAD_URL"
Write-Host ""

# Use curl.exe for multipart upload (PowerShell Invoke-WebRequest doesn't support -Form in older versions)
$curlArgs = @(
    "-X", "POST",
    $UPLOAD_URL,
    "-F", "bundle=@$bundlePath",
    "-v"
)

Write-Host "Running: curl.exe $($curlArgs -join ' ')"
Write-Host ""

& curl.exe $curlArgs

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Bundle: $BUNDLE_NAME"
Write-Host "Domain: $DOMAIN"
Write-Host ""
Write-Host "Check the gateway logs for compilation status."
Write-Host "Access your API at: https://$DOMAIN/api/"
Write-Host ""

# Cleanup
Remove-Item -Path $TEMP_DIR -Recurse -Force
Write-Host "Cleaned up temporary files."

