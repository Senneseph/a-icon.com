# Fix imports in all handler files

$handlers = @(
    "favicons-upload",
    "favicons-canvas",
    "favicons-get",
    "directory",
    "admin-login",
    "admin-logout",
    "admin-verify",
    "admin-delete",
    "storage-source",
    "storage-asset"
)

foreach ($handler in $handlers) {
    $file = "handlers\$handler\src\main.rs"
    if (Test-Path $file) {
        Write-Host "Fixing imports in $file..." -ForegroundColor Cyan
        $content = Get-Content $file -Raw
        $content = $content -replace 'use rust_edge_gateway_sdk::prelude::\*;', 'use rust_edge_gateway_sdk::{prelude::*, handler_loop};'
        Set-Content $file -Value $content -NoNewline
        Write-Host "✓ Fixed $file" -ForegroundColor Green
    } else {
        Write-Host "✗ File not found: $file" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "All imports fixed!" -ForegroundColor Green

