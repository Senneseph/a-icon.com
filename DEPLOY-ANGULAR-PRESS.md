# Deploy angular-press to angular-press.iffuso.com

This guide shows you how to deploy the angular-press Angular application to https://angular-press.iffuso.com on the a-icon.com droplet.

## Prerequisites

✅ **Already configured:**
- ✅ Droplet is running at 167.71.191.234
- ✅ DNS record: angular-press.iffuso.com → 167.71.191.234
- ✅ Nginx configured for static hosting
- ✅ SSL certificate from Let's Encrypt
- ✅ Site directory: `/var/www/angular-press.iffuso.com/`

**You need:**
- Node.js 22.12+ installed locally
- angular-press repository cloned locally
- SSH access to the droplet (already configured)

## Quick Start (Automated Deployment)

### Step 1: Clone angular-press Repository

```powershell
# Navigate to your projects directory
cd D:\Projects\LIFELIKE

# Clone the repository (if not already cloned)
git clone https://github.com/Senneseph/angular-press.git

# Your directory structure should be:
# D:\Projects\LIFELIKE\
# ├── a-icon.com\          (this repo)
# └── angular-press\       (angular-press repo)
```

### Step 2: Run the Deployment Script

```powershell
# Navigate to a-icon.com directory
cd D:\Projects\LIFELIKE\a-icon.com

# Run the deployment script
.\deploy-angular-press.ps1
```

**What the script does:**
1. ✅ Checks if angular-press repository exists
2. ✅ Installs npm dependencies (if needed)
3. ✅ Builds the Angular app for production
4. ✅ Uploads the build to the droplet
5. ✅ Site is immediately live at https://angular-press.iffuso.com

### Step 3: Verify Deployment

Visit: **https://angular-press.iffuso.com**

---

## Manual Deployment (Alternative)

If you prefer to deploy manually or need more control:

### Step 1: Build Locally

```powershell
# Navigate to angular-press directory
cd D:\Projects\LIFELIKE\angular-press

# Install dependencies
npm install

# Build for production
npm run build -- --configuration production
```

### Step 2: Upload to Droplet

```powershell
# Navigate back to a-icon.com directory
cd D:\Projects\LIFELIKE\a-icon.com

# Upload the build (adjust path if needed)
scp -i "$env:USERPROFILE\.ssh\a-icon-deploy" -r ../angular-press/dist/angular-press/browser/* ubuntu@167.71.191.234:/var/www/angular-press.iffuso.com/
```

**Note**: The build output path may vary depending on your Angular version:
- Angular 17+: `dist/angular-press/browser/`
- Angular 16-: `dist/angular-press/`

### Step 3: Verify

Visit: **https://angular-press.iffuso.com**

---

## Updating the Site

To update the site after making changes:

```powershell
# Option 1: Use the deployment script (recommended)
cd D:\Projects\LIFELIKE\a-icon.com
.\deploy-angular-press.ps1

# Option 2: Manual update
cd D:\Projects\LIFELIKE\angular-press
npm run build -- --configuration production
cd ../a-icon.com
scp -i "$env:USERPROFILE\.ssh\a-icon-deploy" -r ../angular-press/dist/angular-press/browser/* ubuntu@167.71.191.234:/var/www/angular-press.iffuso.com/
```

---

## Script Options

The deployment script supports several options:

```powershell
# Skip the build step (use existing build)
.\deploy-angular-press.ps1 -SkipBuild

# Skip the upload step (just build)
.\deploy-angular-press.ps1 -SkipUpload

# Use a different source path
.\deploy-angular-press.ps1 -SourcePath "C:\path\to\angular-press"

# Combine options
.\deploy-angular-press.ps1 -SkipBuild -SourcePath "../angular-press"
```

---

## Troubleshooting

### "angular-press repository not found"

**Solution**: Clone the repository first:
```powershell
cd D:\Projects\LIFELIKE
git clone https://github.com/Senneseph/angular-press.git
```

### "Build failed"

**Solution**: Check Node.js version and dependencies:
```powershell
node --version  # Should be 22.12+
cd ../angular-press
npm install
npm run build
```

### "Could not find build output (index.html)"

**Solution**: The build output path may be different. Check these locations:
- `dist/angular-press/browser/index.html`
- `dist/angular-press/index.html`
- `dist/browser/index.html`
- `dist/index.html`

Update the script's `$possiblePaths` array if needed.

### "Upload failed"

**Solution**: Check SSH connection:
```powershell
ssh -i "$env:USERPROFILE\.ssh\a-icon-deploy" ubuntu@167.71.191.234 "echo 'SSH OK'"
```

### Site shows old content

**Solution**: Hard refresh the browser:
- Chrome/Edge: `Ctrl + Shift + R`
- Firefox: `Ctrl + F5`
- Or clear browser cache

---

## Architecture

```
Local Machine                          Droplet (167.71.191.234)
─────────────                          ────────────────────────

angular-press/                         /var/www/angular-press.iffuso.com/
├── src/                               ├── index.html
├── package.json                       ├── main.*.js
└── dist/                              ├── polyfills.*.js
    └── angular-press/                 ├── styles.*.css
        └── browser/        ──SCP──>   └── assets/
            ├── index.html                 └── ...
            ├── *.js
            └── assets/
                                       Nginx (Port 443)
                                       ├── SSL: Let's Encrypt
                                       ├── Gzip: Enabled
                                       ├── Caching: 1 year
                                       └── SPA: Fallback to index.html

                                       ↓
                                       
                                       https://angular-press.iffuso.com
```

---

## Next Steps

1. ✅ Clone angular-press repository
2. ✅ Run `.\deploy-angular-press.ps1`
3. ✅ Visit https://angular-press.iffuso.com
4. ✅ Make changes to angular-press
5. ✅ Re-run `.\deploy-angular-press.ps1` to update

Happy deploying! 🚀

