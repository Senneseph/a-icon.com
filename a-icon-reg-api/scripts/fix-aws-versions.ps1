# Fix AWS SDK versions for all handlers

$CARGO = "C:\Users\blank-banshee\.cargo\bin\cargo.exe"

$handlers = @(
    "favicons-upload",
    "favicons-canvas",
    "admin-login",
    "admin-logout",
    "admin-verify",
    "admin-delete",
    "storage-source",
    "storage-asset"
)

Write-Host "Downgrading AWS SDK versions for all handlers..." -ForegroundColor Cyan
Write-Host ""

foreach ($handler in $handlers) {
    Write-Host "Fixing $handler..." -ForegroundColor Yellow
    
    $handlerPath = "a-icon-reg-api/handlers/$handler"
    
    if (-not (Test-Path $handlerPath)) {
        Write-Host "  SKIP (directory not found)" -ForegroundColor Yellow
        continue
    }
    
    Push-Location $handlerPath
    
    & $CARGO update aws-sdk-s3 --precise 1.50.0 2>&1 | Out-Null
    & $CARGO update aws-config --precise 1.5.0 2>&1 | Out-Null
    & $CARGO update aws-sdk-sso --precise 1.40.0 2>&1 | Out-Null
    & $CARGO update aws-sdk-ssooidc --precise 1.40.0 2>&1 | Out-Null
    & $CARGO update aws-sdk-sts --precise 1.40.0 2>&1 | Out-Null
    
    Pop-Location
    
    Write-Host "  Done" -ForegroundColor Green
}

Write-Host ""
Write-Host "All AWS SDK versions downgraded!" -ForegroundColor Green

