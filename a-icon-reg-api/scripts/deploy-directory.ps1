# Rust Edge Gateway - Deploy Directory Endpoint
# Usage: .\scripts\deploy-directory.ps1

$ErrorActionPreference = "Stop"

# Load .env file from parent directory
$envFilePath = "..\.env"
if (Test-Path $envFilePath) {
    Get-Content $envFilePath | ForEach-Object {
        if ($_ -match '^([^#][^=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "env:$name" -Value $value
        }
    }
}

# Validate required variables
if (-not $env:RUST_EDGE_GATEWAY_API_KEY) {
    Write-Error "RUST_EDGE_GATEWAY_API_KEY not set in .env"
    exit 1
}

if (-not $env:TARGET_DOMAIN) {
    Write-Error "TARGET_DOMAIN not set in .env"
    exit 1
}

$API_KEY = $env:RUST_EDGE_GATEWAY_API_KEY
$GATEWAY_DOMAIN = $env:RUST_EDGE_GATEWAY_DOMAIN
$TARGET_DOMAIN = $env:TARGET_DOMAIN
$BASE_URL = "https://$GATEWAY_DOMAIN"

Write-Host "=== Deploying Directory Endpoint ===" -ForegroundColor Green
Write-Host "Target Domain: $env:TARGET_DOMAIN"
Write-Host "API Key: $($API_KEY.Substring(0, 8))..."
Write-Host ""

# Read the handler code as a single string
$handlerCode = [string](Get-Content -Path "handlers\directory\src\main.rs" -Raw)

# Step 1: Create Domain (if it doesn't exist)
Write-Host "Step 1: Creating domain 'api'..." -ForegroundColor Cyan

$domainData = @{
name = "api"
host = $TARGET_DOMAIN
description = "API Domain"
} | ConvertTo-Json -Compress

try {
    $domainResponse = Invoke-RestMethod -Uri "$BASE_URL/api/domains" -Method Post -Headers @{"Authorization" = "Bearer $API_KEY"; "Content-Type" = "application/json"} -Body $domainData -ErrorAction Stop
    
    if ($domainResponse.success -eq $true -and $domainResponse.data) {
        $domainId = $domainResponse.data.id
        Write-Host "Domain created successfully. ID: $domainId" -ForegroundColor Green
    } else {
        # Creation failed - might already exist
        throw "Domain creation returned: $($domainResponse | ConvertTo-Json -Compress)"
    }
} catch {
    # Check if domain already exists
    $existingDomains = Invoke-RestMethod -Uri "$BASE_URL/api/domains" -Method Get -Headers @{"Authorization" = "Bearer $API_KEY"} -ErrorAction Stop
    
    $domain = $existingDomains.data | Where-Object { $_.name -eq "api" }
    if ($domain) {
        $domainId = $domain.id
        Write-Host "Domain 'api' already exists. Using ID: $domainId" -ForegroundColor Yellow
    } else {
        Write-Error "Failed to create domain: $_"
        exit 1
    }
}

# Step 2: Create Collection (if it doesn't exist)
Write-Host "" 
Write-Host "Step 2: Creating collection 'directory'..." -ForegroundColor Cyan

$collectionData = @{
    domain_id = $domainId
    name = "directory"
    description = "Directory Collection"
    base_path = "/api"
} | ConvertTo-Json -Compress

try {
    $collectionResponse = Invoke-RestMethod -Uri "$BASE_URL/api/collections" -Method Post -Headers @{"Authorization" = "Bearer $API_KEY"; "Content-Type" = "application/json"} -Body $collectionData -ErrorAction Stop
    
    $collectionId = $collectionResponse.data.id
    Write-Host "Collection created successfully. ID: $collectionId" -ForegroundColor Green
} catch {
    # Check if collection already exists
    $existingCollections = Invoke-RestMethod -Uri "$BASE_URL/api/collections" -Method Get -Headers @{"Authorization" = "Bearer $API_KEY"} -ErrorAction Stop
    
    $collection = $existingCollections.data | Where-Object { $_.name -eq "directory" }
    if ($collection) {
        $collectionId = $collection.id
        Write-Host "Collection 'directory' already exists. Using ID: $collectionId" -ForegroundColor Yellow
    } else {
        Write-Error "Failed to create collection: $_"
        exit 1
    }
}

# Step 3: Create Endpoint
Write-Host "" 
Write-Host "Step 3: Creating endpoint 'directory'..." -ForegroundColor Cyan

$endpointData = @{
    collection_id = $collectionId
    name = "directory"
    domain = $TARGET_DOMAIN
    path = "/api/directory"
    method = "GET"
    description = "Directory API Endpoint"
    code = $handlerCode
} | ConvertTo-Json -Compress

try {
    $endpointResponse = Invoke-RestMethod -Uri "$BASE_URL/api/endpoints" -Method Post -Headers @{"Authorization" = "Bearer $API_KEY"; "Content-Type" = "application/json"} -Body $endpointData -ErrorAction Stop
    
    $endpointId = $endpointResponse.data.id
    Write-Host "Endpoint created successfully. ID: $endpointId" -ForegroundColor Green
} catch {
    # Check if endpoint already exists
    $existingEndpoints = Invoke-RestMethod -Uri "$BASE_URL/api/endpoints" -Method Get -Headers @{"Authorization" = "Bearer $API_KEY"} -ErrorAction Stop
    
    $endpoint = $existingEndpoints.data | Where-Object { $_.name -eq "directory" }
    if ($endpoint) {
        $endpointId = $endpoint.id
        Write-Host "Endpoint 'directory' already exists. Using ID: $endpointId" -ForegroundColor Yellow
        
        # Update the endpoint code if it exists
        Write-Host "Updating endpoint code..." -ForegroundColor Cyan
        $updateCodeData = @{
            code = $handlerCode
        } | ConvertTo-Json -Compress
        
        Invoke-RestMethod -Uri "$BASE_URL/api/endpoints/$endpointId/code" -Method Put -Headers @{"Authorization" = "Bearer $API_KEY"; "Content-Type" = "application/json"} -Body $updateCodeData -ErrorAction Stop | Out-Null
        
        Write-Host "Endpoint code updated successfully." -ForegroundColor Green
    } else {
        Write-Error "Failed to create endpoint: $_"
        exit 1
    }
}

# Step 4: Compile the Endpoint
Write-Host "" 
Write-Host "Step 4: Compiling endpoint..." -ForegroundColor Cyan

try {
    $compileResponse = Invoke-RestMethod -Uri "$BASE_URL/api/endpoints/$endpointId/compile" -Method Post -Headers @{"Authorization" = "Bearer $API_KEY"} -ErrorAction Stop
    
    Write-Host "Endpoint compiled successfully: $($compileResponse.data)" -ForegroundColor Green
} catch {
    Write-Error "Failed to compile endpoint: $_"
    exit 1
}

# Step 5: Start the Endpoint
Write-Host "" 
Write-Host "Step 5: Starting endpoint..." -ForegroundColor Cyan

try {
    $startResponse = Invoke-RestMethod -Uri "$BASE_URL/api/endpoints/$endpointId/start" -Method Post -Headers @{"Authorization" = "Bearer $API_KEY"} -ErrorAction Stop
    
    Write-Host "Endpoint started successfully." -ForegroundColor Green
} catch {
    Write-Error "Failed to start endpoint: $_"
    exit 1
}

# Step 6: Test the Endpoint
Write-Host "" 
Write-Host "Step 6: Testing endpoint..." -ForegroundColor Cyan

try {
    $testResponse = Invoke-RestMethod -Uri "https://$TARGET_DOMAIN/api/directory" -Method Get -Headers @{"Authorization" = "Bearer $API_KEY"} -ErrorAction Stop
    
    Write-Host "Endpoint test successful!" -ForegroundColor Green
    Write-Host "Response: $($testResponse | ConvertTo-Json -Depth 10)" -ForegroundColor Cyan
} catch {
    Write-Error "Failed to test endpoint: $_"
    exit 1
}

Write-Host "" 
Write-Host "=== Directory Endpoint Deployment Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your endpoint is now available at:" -ForegroundColor Green
Write-Host "  https://$TARGET_DOMAIN/api/directory" -ForegroundColor Cyan
Write-Host ""
Write-Host "To test it manually:" -ForegroundColor Green
Write-Host "  curl -H \"Authorization: Bearer $API_KEY\" https://$TARGET_DOMAIN/api/directory" -ForegroundColor Cyan