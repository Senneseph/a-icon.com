# Configuration
$REG_URL = if ($env:REG_URL) { $env:REG_URL } else { "https://rust-edge-gateway.iffuso.com" }
$DOMAIN = if ($env:DOMAIN) { $env:DOMAIN } else { "a-icon.com" }
$COMPILE = if ($env:COMPILE) { $env:COMPILE } else { "true" }
$START = if ($env:START) { $env:START } else { "true" }
$BUNDLE_NAME = "a-icon-api-bundle.zip"

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

# Login to Admin UI to obtain session token
Write-Host "Logging in to Admin UI..." -ForegroundColor Cyan
$LOGIN_URL = "$REG_URL/auth/login"

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

$loginArgs = @(
    "-X", "POST",
    $LOGIN_URL,
    "-H", "Content-Type: application/json",
    "-d", '{"username": "' + $ADMIN_USERNAME + '", "password": "' + $ADMIN_PASSWORD + '", "recaptcha_token": "test-token"}',
    "-v"
)

Write-Host "Running: curl.exe $($loginArgs -join ' ')"
Write-Host ""

$loginResponse = & curl.exe $loginArgs

# Extract session cookie from login response
$sessionCookieMatch = [regex]::Match($loginResponse, 'Set-Cookie: ([^;]+)')
if ($sessionCookieMatch.Success) {
    $SESSION_COOKIE = $sessionCookieMatch.Groups[1].Value.Trim()
    Write-Host "Session Cookie: $($SESSION_COOKIE.Substring(0, 20))..." -ForegroundColor Green
} else {
    Write-Host "ERROR: Failed to obtain session cookie" -ForegroundColor Red
    Write-Host "Login Response: $loginResponse" -ForegroundColor Red
    exit 1
}

# Use curl.exe for multipart upload with session cookie
$curlArgs = @(
    "-X", "POST",
    $UPLOAD_URL,
    "-H", "Cookie: $SESSION_COOKIE",
    "-F", "bundle=@$bundlePath",
    "-v"
)

Write-Host "Running: curl.exe $($curlArgs -join ' ')"
Write-Host ""

& curl.exe $curlArgs

# Logout from Admin UI
Write-Host "Logging out from Admin UI..." -ForegroundColor Cyan
$LOGOUT_URL = "$REG_URL/auth/logout"

$logoutArgs = @(
    "-X", "POST",
    $LOGOUT_URL,
    "-H", "Cookie: $SESSION_COOKIE",
    "-v"
)

Write-Host "Running: curl.exe $($logoutArgs -join ' ')"
Write-Host ""

& curl.exe $logoutArgs

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

