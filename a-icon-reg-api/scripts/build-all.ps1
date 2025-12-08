# Build all handlers for Rust Edge Gateway

$CARGO = "C:\Users\blank-banshee\.cargo\bin\cargo.exe"

$handlers = @(
    "health",
    "directory",
    "favicons-get",
    "favicons-upload",
    "favicons-canvas",
    "admin-login",
    "admin-logout",
    "admin-verify",
    "admin-delete",
    "storage-source",
    "storage-asset"
)

Write-Host "Building all handlers..." -ForegroundColor Cyan
Write-Host ""

$built = 0
$failed = 0
$failedHandlers = @()

foreach ($handler in $handlers) {
    Write-Host -NoNewline "Building $handler... "

    $handlerPath = "a-icon-reg-api/handlers/$handler"

    if (-not (Test-Path $handlerPath)) {
        Write-Host "SKIP (directory not found)" -ForegroundColor Yellow
        continue
    }

    $output = & $CARGO build --release --manifest-path "$handlerPath/Cargo.toml" 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        Write-Host "OK" -ForegroundColor Green
        $built++
    } else {
        Write-Host "FAILED" -ForegroundColor Red
        $failed++
        $failedHandlers += $handler
        Write-Host "Error output:" -ForegroundColor Red
        $output | Select-Object -Last 10 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "Build Summary:" -ForegroundColor Cyan
Write-Host "  Built: $built" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "  Failed: $failed" -ForegroundColor Red
} else {
    Write-Host "  Failed: $failed" -ForegroundColor Green
}

if ($failed -gt 0) {
    Write-Host ""
    Write-Host "Failed handlers:" -ForegroundColor Red
    $failedHandlers | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}

Write-Host ""
Write-Host "All handlers built successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Binaries location:" -ForegroundColor Cyan
foreach ($handler in $handlers) {
    $binary = "a-icon-reg-api/handlers/$handler/target/release/$handler.exe"
    if (Test-Path $binary) {
        $size = (Get-Item $binary).Length / 1MB
        $sizeStr = [math]::Round($size, 2)
        Write-Host "  + $handler ($sizeStr MB)" -ForegroundColor Green
    }
}

