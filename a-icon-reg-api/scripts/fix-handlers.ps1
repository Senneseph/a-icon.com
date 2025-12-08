# Fix all handlers to use correct SDK API

$handlers = @(
    "favicons-canvas",
    "admin-login",
    "admin-logout",
    "admin-verify",
    "admin-delete",
    "storage-source",
    "storage-asset"
)

foreach ($handler in $handlers) {
    Write-Host "Fixing $handler..." -ForegroundColor Cyan
    $file = "handlers\$handler\src\main.rs"
    
    if (!(Test-Path $file)) {
        Write-Host "  File not found: $file" -ForegroundColor Red
        continue
    }
    
    $content = Get-Content $file -Raw
    
    # Remove #[tokio::main] and async fn main
    $content = $content -replace '#\[tokio::main\]\s+async fn main\(\) \{', 'fn main() {'
    
    # Fix async fn handle to sync
    $content = $content -replace 'async fn handle\(req: Request\) -> Response \{', 'fn handle(req: Request) -> Response {'
    
    # Fix Response::error to Response::json
    $content = $content -replace 'Response::error\(e\.status_code\(\), e\.to_json\(\)\)', 'Response::json(e.status_code(), json!(e.to_json()))'
    
    # Fix async fn handle_* to use runtime
    $content = $content -replace 'async fn (handle_\w+)\(req: Request\) -> ApiResult<Response> \{', @'
fn $1(req: &Request) -> Result<Response, ApiError> {
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| ApiError::InternalError(e.to_string()))?;
    
    rt.block_on(async {
'@
    
    # Fix req.query_params to req.query
    $content = $content -replace 'req\.query_params', 'req.query'
    
    # Fix req.path_params to path parsing
    $content = $content -replace 'req\.path_params\.get\("(\w+)"\)', 'req.path.trim_matches(''/'').split(''/'').last()'
    
    # Fix serde_json::to_value to json! macro
    $content = $content -replace 'serde_json::to_value\(([^)]+)\)\.unwrap\(\)', 'json!($1)'
    
    # Remove ApiResult import
    $content = $content -replace 'error::\{ApiError, ApiResult\}', 'error::ApiError'
    
    # Add closing braces for runtime block before last }
    if ($content -match 'rt\.block_on') {
        # Find the last occurrence of just "}" and add "    })" before it
        $lastBrace = $content.LastIndexOf("`n}")
        if ($lastBrace -gt 0) {
            $content = $content.Substring(0, $lastBrace) + "`n    })`n}" + $content.Substring($lastBrace + 2)
        }
    }
    
    # Add handler_loop! if missing
    if ($content -notmatch 'handler_loop!\(handle\)') {
        $content = $content.TrimEnd() + "`n`nhandler_loop!(handle);`n"
    }
    
    # Save the file
    Set-Content $file $content -NoNewline
    
    Write-Host "  ✓ Fixed $handler" -ForegroundColor Green
}

Write-Host "`nAll handlers fixed!" -ForegroundColor Green
Write-Host "Now run: .\scripts\build-all-handlers.sh" -ForegroundColor Yellow

