# Demo handler deployment script
$REG_URL = "https://rust-edge-gateway.iffuso.com"
$DOMAIN = "a-icon.com"
$BUNDLE_NAME = "demo-api-bundle.zip"

Write-Host "=== Demo API Deployment to Rust Edge Gateway ===" -ForegroundColor Cyan
Write-Host "REG URL: $REG_URL"
Write-Host "Domain: $DOMAIN"
Write-Host ""

# Create temporary directory for bundle
$TEMP_DIR = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ([System.IO.Path]::GetRandomFileName()))
Write-Host "Creating bundle in: $TEMP_DIR"

# Copy openapi.yaml
Write-Host "Copying demo-openapi.yaml..."
Copy-Item "demo-openapi.yaml" -Destination (Join-Path $TEMP_DIR "openapi.yaml")

# Create handlers directory
$handlersDir = New-Item -ItemType Directory -Path (Join-Path $TEMP_DIR "handlers")

# Copy demo handler
Write-Host "Copying demo handler..."
Copy-Item "demo-api.rs" -Destination (Join-Path $handlersDir "demoApi.rs")

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

# Load admin credentials from .env file
$envContent = Get-Content -Path "..\.env" -Raw
$adminUsernameMatch = [regex]::Match($envContent, 'RUST_EDGE_GATEWAY_ADMIN_USERNAME=(.+)')
$adminPasswordMatch = [regex]::Match($envContent, 'RUST_EDGE_GATEWAY_ADMIN_PASSWORD=(.+)')

if ($adminUsernameMatch.Success -and $adminPasswordMatch.Success) {
    $ADMIN_USERNAME = $adminUsernameMatch.Groups[1].Value.Trim()
    $ADMIN_PASSWORD = $adminPasswordMatch.Groups[1].Value.Trim()
    Write-Host "Using Admin Username: $ADMIN_USERNAME" -ForegroundColor Green
} else {
    Write-Host "ERROR: RUST_EDGE_GATEWAY_ADMIN_USERNAME or RUST_EDGE_GATEWAY_ADMIN_PASSWORD not found in .env file" -ForegroundColor Red
    exit 1
}

# Upload to Rust Edge Gateway
Write-Host "Uploading to Rust Edge Gateway..." -ForegroundColor Cyan
$UPLOAD_URL = "$REG_URL/api/import/bundle-with-api-key?domain=$DOMAIN&compile=true&start=true"

Write-Host "Upload URL: $UPLOAD_URL"
Write-Host ""

# Load API key from .env file
$envContent = Get-Content -Path "..\.env" -Raw
$apiKeyMatch = [regex]::Match($envContent, 'RUST_EDGE_GATEWAY_API_KEY=(.+)')
if ($apiKeyMatch.Success) {
    $API_KEY = $apiKeyMatch.Groups[1].Value.Trim()
    Write-Host "Using API Key: $($API_KEY.Substring(0, 8))..." -ForegroundColor Green
} else {
    Write-Host "ERROR: RUST_EDGE_GATEWAY_API_KEY not found in .env file" -ForegroundColor Red
    exit 1
}

# Use curl.exe for multipart upload with API key authentication
$curlArgs = @(
    "-X", "POST",
    $UPLOAD_URL,
    "-H", "Authorization: Bearer $API_KEY",
    "-F", "bundle=@$bundlePath",
    "-v"
)

Write-Host "Running: curl.exe $($curlArgs -join ' ')"
Write-Host ""

& curl.exe $curlArgs

Write-Host ""
Write-Host "=== Demo Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Bundle: $BUNDLE_NAME"
Write-Host "Domain: $DOMAIN"
Write-Host ""
Write-Host "Check the gateway logs for compilation status."
Write-Host "Test the demo endpoint at: https://$DOMAIN/api/demo-api"
Write-Host ""

# Cleanup
Remove-Item -Path $TEMP_DIR -Recurse -Force
Write-Host "Cleaned up temporary files."