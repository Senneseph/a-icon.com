#!/usr/bin/env pwsh
# Deploy angular-press to angular-press.iffuso.com on the a-icon.com droplet
# This script builds the Angular app locally and deploys it as a static site

param(
    [switch]$SkipBuild,
    [switch]$SkipUpload,
    [string]$SourcePath = "../angular-press"
)

$ErrorActionPreference = "Stop"

# Load droplet info
if (-not (Test-Path "droplet-info.json")) {
    Write-Host "ERROR: droplet-info.json not found" -ForegroundColor Red
    exit 1
}

$dropletInfo = Get-Content "droplet-info.json" -Raw | ConvertFrom-Json
$DROPLET_IP = $dropletInfo.droplet_ip
$SSH_KEY = "$env:USERPROFILE\.ssh\a-icon-deploy"
$DOMAIN = "iffuso.com"
$SUBDOMAIN = "angular-press"
$FULL_DOMAIN = "$SUBDOMAIN.$DOMAIN"
$SITE_ROOT = "/var/www/$FULL_DOMAIN"

Write-Host "=== Deploying angular-press to $FULL_DOMAIN ===" -ForegroundColor Green
Write-Host ""

# Step 1: Check if angular-press repo exists
if (-not $SkipBuild) {
    Write-Host "[1/4] Checking angular-press repository..." -ForegroundColor Yellow
    
    if (-not (Test-Path $SourcePath)) {
        Write-Host "  angular-press repository not found at: $SourcePath" -ForegroundColor Red
        Write-Host ""
        Write-Host "Please clone the repository first:" -ForegroundColor Yellow
        Write-Host "  cd .." -ForegroundColor White
        Write-Host "  git clone https://github.com/Senneseph/angular-press.git" -ForegroundColor White
        Write-Host ""
        Write-Host "Or specify a different path:" -ForegroundColor Yellow
        Write-Host "  .\deploy-angular-press.ps1 -SourcePath 'C:\path\to\angular-press'" -ForegroundColor White
        exit 1
    }
    
    Write-Host "  [OK] Found angular-press at: $SourcePath" -ForegroundColor Green
    Write-Host ""
    
    # Step 2: Build the Angular app
    Write-Host "[2/4] Building Angular app..." -ForegroundColor Yellow

    Push-Location $SourcePath

    try {
        # Check if node_modules exists
        if (-not (Test-Path "node_modules")) {
            Write-Host "  Installing dependencies..." -ForegroundColor Cyan
            npm install
        }

        # Build for production
        Write-Host "  Building for production..." -ForegroundColor Cyan

        # Check if package.json has a build:prod or build script
        $packageJson = Get-Content "package.json" -Raw | ConvertFrom-Json

        if ($packageJson.scripts.'build:prod') {
            # Use build:prod if available
            Write-Host "  Using build:prod script" -ForegroundColor Cyan
            npm run build:prod
        }
        elseif ($packageJson.scripts.build) {
            $buildScript = $packageJson.scripts.build

            if ($buildScript -like "*vite*") {
                # Vite build (no --configuration flag)
                Write-Host "  Detected Vite build" -ForegroundColor Cyan
                npm run build
            }
            elseif ($buildScript -like "*ng build*") {
                # Angular CLI build - try client-only build first for static hosting
                Write-Host "  Detected Angular CLI build" -ForegroundColor Cyan
                Write-Host "  Attempting client-only build for static hosting..." -ForegroundColor Cyan

                # Try building with --output-mode=static to skip SSR
                npm run build -- --configuration production --output-mode=static 2>$null

                if ($LASTEXITCODE -ne 0) {
                    Write-Host "  Static build failed, trying standard build..." -ForegroundColor Yellow
                    npm run build -- --configuration production
                }
            }
            else {
                # Generic build
                Write-Host "  Using generic build command" -ForegroundColor Cyan
                npm run build
            }
        }
        else {
            throw "No build script found in package.json"
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Build failed"
        }

        Write-Host "  [OK] Build completed" -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR: Build failed: $_" -ForegroundColor Red
        Pop-Location
        exit 1
    }
    finally {
        Pop-Location
    }
    
    Write-Host ""
} else {
    Write-Host "[1/4] Skipping build (using existing build)" -ForegroundColor Cyan
    Write-Host "[2/4] Skipping build (using existing build)" -ForegroundColor Cyan
    Write-Host ""
}

# Step 3: Find the build output directory
Write-Host "[3/4] Locating build output..." -ForegroundColor Yellow

$distPath = $null
$possiblePaths = @(
    "$SourcePath/dist/angular-press/browser",
    "$SourcePath/dist/angular-press",
    "$SourcePath/dist/browser",
    "$SourcePath/dist",
    "$SourcePath/build"
)

foreach ($path in $possiblePaths) {
    if (Test-Path "$path/index.html") {
        $distPath = $path
        break
    }
}

if (-not $distPath) {
    Write-Host "  ERROR: Could not find build output (index.html)" -ForegroundColor Red
    Write-Host "  Searched in:" -ForegroundColor Yellow
    foreach ($path in $possiblePaths) {
        Write-Host "    - $path" -ForegroundColor White
    }
    exit 1
}

Write-Host "  [OK] Found build output at: $distPath" -ForegroundColor Green
Write-Host ""

# Step 4: Upload to droplet
if (-not $SkipUpload) {
    Write-Host "[4/4] Uploading to droplet..." -ForegroundColor Yellow
    
    # Create a temporary directory for the upload
    $tempDir = [System.IO.Path]::GetTempPath() + "angular-press-deploy-" + [System.Guid]::NewGuid().ToString()
    New-Item -ItemType Directory -Path $tempDir | Out-Null
    
    try {
        # Copy files to temp directory
        Write-Host "  Preparing files..." -ForegroundColor Cyan
        Copy-Item -Path "$distPath/*" -Destination $tempDir -Recurse -Force
        
        # Upload via SCP
        Write-Host "  Uploading to $FULL_DOMAIN..." -ForegroundColor Cyan
        
        # First, clear the existing directory on the server
        ssh -i $SSH_KEY ubuntu@$DROPLET_IP "rm -rf $SITE_ROOT/* $SITE_ROOT/.*[!.] 2>/dev/null || true"
        
        # Upload new files
        scp -i $SSH_KEY -r "$tempDir/*" ubuntu@${DROPLET_IP}:$SITE_ROOT/
        
        if ($LASTEXITCODE -ne 0) {
            throw "Upload failed"
        }
        
        Write-Host "  [OK] Upload completed" -ForegroundColor Green
    }
    catch {
        Write-Host "  ERROR: Upload failed: $_" -ForegroundColor Red
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        exit 1
    }
    finally {
        # Clean up temp directory
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "[4/4] Skipping upload" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "=== Deployment Complete! ===" -ForegroundColor Green
Write-Host ""
Write-Host "Your angular-press app is now live at:" -ForegroundColor Cyan
Write-Host "  https://$FULL_DOMAIN" -ForegroundColor White
Write-Host ""
Write-Host "To update the site in the future:" -ForegroundColor Yellow
Write-Host "  .\deploy-angular-press.ps1" -ForegroundColor White
Write-Host ""

