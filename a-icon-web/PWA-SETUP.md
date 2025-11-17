# Progressive Web App (PWA) Setup

This document describes the PWA implementation for a-icon.com, enabling installation on desktop and mobile devices (iOS, Android, Windows, macOS, Linux).

## 📱 Features

- **Installable**: Users can install the app on their home screen/desktop
- **Offline Support**: Service worker caches assets for offline functionality
- **App-like Experience**: Runs in standalone mode without browser UI
- **Cross-Platform**: Works on iOS, Android, Windows, macOS, and Linux
- **Auto-Updates**: Service worker automatically updates when new versions are deployed

## 🗂️ Files Created

### Core PWA Files

1. **`public/manifest.json`** - Web App Manifest
   - Defines app metadata (name, icons, colors, display mode)
   - Configures app shortcuts and screenshots
   - Required for installation on all platforms

2. **`public/sw.js`** - Service Worker
   - Handles offline caching and asset management
   - Implements cache-first strategy for static assets
   - Network-first strategy for HTML pages
   - Automatically cleans up old caches

3. **`public/register-sw.js`** - Service Worker Registration
   - Registers the service worker on page load
   - Handles update notifications
   - Manages install prompts

4. **`public/browserconfig.xml`** - Microsoft Tiles Configuration
   - Configures Windows tile icons and colors
   - Required for Windows Start Menu tiles

### Icon Assets

All icons are generated in `public/assets/icons/`:

- **Standard PWA Icons**: 72x72, 96x96, 128x128, 144x144, 152x152, 192x192, 384x384, 512x512
- **Maskable Icons**: 192x192, 512x512 (with safe zone padding for Android)
- **Apple Touch Icons**: 57x57, 60x60, 76x76, 114x114, 120x120, 180x180

### Updated Files

- **`src/index.html`** - Added PWA meta tags, manifest link, and service worker registration

## 🚀 Installation Instructions

### For Users

#### **Android (Chrome, Edge, Samsung Internet)**
1. Visit https://a-icon.com
2. Tap the menu (⋮) → "Install app" or "Add to Home screen"
3. Confirm installation
4. App appears on home screen and app drawer

#### **iOS (Safari)**
1. Visit https://a-icon.com in Safari
2. Tap the Share button (□↑)
3. Scroll down and tap "Add to Home Screen"
4. Tap "Add"
5. App appears on home screen

#### **Windows (Chrome, Edge)**
1. Visit https://a-icon.com
2. Click the install icon (⊕) in the address bar
3. Or: Menu (⋮) → "Install a-icon.com"
4. Confirm installation
5. App appears in Start Menu and Desktop

#### **macOS (Chrome, Edge, Safari)**
1. Visit https://a-icon.com
2. Click the install icon in the address bar
3. Or: Menu → "Install a-icon.com"
4. App appears in Applications folder and Dock

#### **Linux (Chrome, Edge)**
1. Visit https://a-icon.com
2. Click the install icon in the address bar
3. Or: Menu → "Install a-icon.com"
4. App appears in application menu

## 🔧 Development

### Regenerating Icons

If you update the logo, regenerate all PWA icons:

```bash
# From project root
node a-icon-web/generate-pwa-icons.js
```

This will regenerate all icon sizes from `public/assets/images/logo-png.png`.

### Testing PWA Locally

1. **Build and serve the app**:
   ```bash
   docker-compose up --build
   ```

2. **Access at**: http://localhost:4200

3. **Test installation**:
   - Chrome DevTools → Application → Manifest
   - Check for errors in manifest
   - Test "Add to home screen" functionality

4. **Test Service Worker**:
   - Chrome DevTools → Application → Service Workers
   - Verify service worker is registered
   - Test offline mode (Network → Offline)

### PWA Audit

Use Lighthouse to audit PWA compliance:

1. Open Chrome DevTools
2. Go to Lighthouse tab
3. Select "Progressive Web App" category
4. Run audit
5. Fix any issues reported

## 📊 PWA Manifest Details

- **Name**: a-icon.com - Favicon Generator
- **Short Name**: a-icon.com
- **Theme Color**: #667eea (purple-blue gradient)
- **Background Color**: #f5f7fa (light gray)
- **Display Mode**: standalone (full-screen, no browser UI)
- **Orientation**: any (supports portrait and landscape)

## 🔄 Service Worker Caching Strategy

### Precached Assets (on install)
- `/` (home page)
- `/manifest.json`
- `/favicon.ico`
- Logo images

### Runtime Caching
- **HTML Pages**: Network-first (always try network, fallback to cache)
- **Static Assets**: Cache-first (serve from cache, update in background)
- **API Requests**: Network-only (never cached)

### Cache Versioning
- Cache name: `a-icon-v1`
- Runtime cache: `a-icon-runtime-v1`
- Old caches are automatically deleted on service worker activation

## 🎯 Browser Support

| Platform | Browser | Installation | Offline |
|----------|---------|--------------|---------|
| Android | Chrome 80+ | ✅ | ✅ |
| Android | Edge 80+ | ✅ | ✅ |
| Android | Samsung Internet | ✅ | ✅ |
| iOS | Safari 11.3+ | ✅ | ⚠️ Limited |
| Windows | Chrome 80+ | ✅ | ✅ |
| Windows | Edge 80+ | ✅ | ✅ |
| macOS | Chrome 80+ | ✅ | ✅ |
| macOS | Safari 15.4+ | ✅ | ⚠️ Limited |
| Linux | Chrome 80+ | ✅ | ✅ |

**Note**: iOS Safari has limited service worker support. Offline functionality may be restricted.

## 🔐 Security Considerations

- Service worker only works over HTTPS (or localhost for development)
- Production deployment at https://a-icon.com uses HTTPS
- Service worker has access to all same-origin requests
- Cache is isolated per origin

## 📝 Next Steps

1. ✅ PWA manifest created
2. ✅ Service worker implemented
3. ✅ Icons generated
4. ✅ Meta tags added
5. ⏳ Deploy to production
6. ⏳ Test installation on real devices
7. ⏳ Run Lighthouse PWA audit
8. ⏳ (Optional) Add app screenshots to manifest
9. ⏳ (Optional) Implement custom install prompt UI

## 🐛 Troubleshooting

### "Add to Home Screen" not showing
- Ensure you're on HTTPS (or localhost)
- Check manifest.json is accessible
- Verify service worker is registered
- Check browser console for errors

### Service Worker not updating
- Hard refresh (Ctrl+Shift+R / Cmd+Shift+R)
- Clear browser cache
- Unregister old service worker in DevTools

### Icons not displaying
- Verify icon files exist in `/assets/icons/`
- Check manifest.json icon paths
- Regenerate icons if needed

## 📚 Resources

- [Web App Manifest Spec](https://www.w3.org/TR/appmanifest/)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)
- [PWA Best Practices](https://web.dev/pwa/)
- [Maskable Icons](https://web.dev/maskable-icon/)

