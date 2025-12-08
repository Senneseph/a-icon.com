# Manual Deployment Guide for angular-press (SSR App)

## Issue

The `angular-press` app at `D:\Projects\LIFELIKE\Antecedant\playground\wp-angular-app\angular-press` is configured for **Server-Side Rendering (SSR)** with prerendering, which requires additional configuration that's currently missing.

### Build Error:
```
X [ERROR] The 'post/:slug' route uses prerendering and includes parameters, 
but 'getPrerenderParams' is missing.

X [ERROR] The 'ap-admin/posts/:id' route uses prerendering and includes parameters, 
but 'getPrerenderParams' is missing.
```

## Solution: Deploy as Client-Side Only App

Since you're deploying to **static hosting** (Nginx), you don't need SSR. Here's how to deploy the client-side bundle only:

### Option 1: Modify angular.json (Recommended)

1. **Open** `D:\Projects\LIFELIKE\Antecedant\playground\wp-angular-app\angular-press\angular.json`

2. **Find** the `production` configuration under `projects > angular-press > architect > build > configurations > production`

3. **Add or modify** these settings:
   ```json
   "production": {
     "outputMode": "static",
     "prerender": false,
     "ssr": false,
     ...
   }
   ```

4. **Save** and try building again:
   ```powershell
   cd D:\Projects\LIFELIKE\Antecedant\playground\wp-angular-app\angular-press
   npm run build -- --configuration production
   ```

5. **Deploy** using the script:
   ```powershell
   cd D:\Projects\LIFELIKE\a-icon.com
   .\deploy-angular-press.ps1 -SourcePath 'D:\Projects\LIFELIKE\Antecedant\playground\wp-angular-app\angular-press'
   ```

### Option 2: Use Development Build (Quick Test)

For a quick test, you can build without production optimizations:

```powershell
# Build for development (no SSR/prerendering)
cd D:\Projects\LIFELIKE\Antecedant\playground\wp-angular-app\angular-press
npm run build

# Check if browser bundle was created
Test-Path dist/angular-press/browser/index.html

# If yes, deploy manually
cd D:\Projects\LIFELIKE\a-icon.com
scp -i "$env:USERPROFILE\.ssh\a-icon-deploy" -r ../Antecedant/playground/wp-angular-app/angular-press/dist/angular-press/browser/* ubuntu@167.71.191.234:/var/www/angular-press.iffuso.com/
```

### Option 3: Fix SSR Configuration

If you want to keep SSR/prerendering, you need to add `getPrerenderParams` functions:

1. **Create or edit** `src/app/app.routes.server.ts`

2. **Add** the `getPrerenderParams` function:
   ```typescript
   import { RenderMode, ServerRoute } from '@angular/ssr';

   export const serverRoutes: ServerRoute[] = [
     {
       path: 'post/:slug',
       renderMode: RenderMode.Prerender,
       async getPrerenderParams() {
         // Return list of slugs to prerender
         return [
           { slug: 'example-post-1' },
           { slug: 'example-post-2' },
         ];
       },
     },
     {
       path: 'ap-admin/posts/:id',
       renderMode: RenderMode.Client, // Or skip prerendering for admin routes
     },
     {
       path: '**',
       renderMode: RenderMode.Prerender,
     },
   ];
   ```

3. **Build** again:
   ```powershell
   npm run build -- --configuration production
   ```

## Recommended Approach

**For static hosting on Nginx, use Option 1** (disable SSR/prerendering). SSR is only needed if you're running a Node.js server, which we're not doing on the droplet.

### Quick Fix Command

```powershell
# Navigate to angular-press
cd D:\Projects\LIFELIKE\Antecedant\playground\wp-angular-app\angular-press

# Build without SSR (development mode)
npm run build

# Verify browser bundle exists
ls dist/angular-press/browser/

# Deploy manually
cd D:\Projects\LIFELIKE\a-icon.com
scp -i "$env:USERPROFILE\.ssh\a-icon-deploy" -r ../Antecedant/playground/wp-angular-app/angular-press/dist/angular-press/browser/* ubuntu@167.71.191.234:/var/www/angular-press.iffuso.com/

# Visit the site
# https://angular-press.iffuso.com
```

## Next Steps

1. Choose one of the options above
2. Fix the build configuration
3. Run the deployment script or deploy manually
4. Visit https://angular-press.iffuso.com to verify

---

**Need help?** The issue is that the app is trying to pre-generate HTML for routes with dynamic parameters (like `/post/:slug`), but it doesn't know which values to use for `:slug`. For static hosting, you don't need this feature - just disable SSR/prerendering.

