// Register Service Worker for PWA functionality
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker
      .register('/sw.js')
      .then((registration) => {
        console.log('[PWA] Service Worker registered:', registration.scope);

        // Check for updates periodically
        setInterval(() => {
          registration.update();
        }, 60000); // Check every minute

        // Handle updates
        registration.addEventListener('updatefound', () => {
          const newWorker = registration.installing;
          
          newWorker.addEventListener('statechange', () => {
            if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
              // New service worker available, show update notification
              console.log('[PWA] New version available! Refresh to update.');
              
              // Optionally, you can show a notification to the user
              if (confirm('A new version of a-icon.com is available. Reload to update?')) {
                newWorker.postMessage({ type: 'SKIP_WAITING' });
                window.location.reload();
              }
            }
          });
        });
      })
      .catch((error) => {
        console.error('[PWA] Service Worker registration failed:', error);
      });

    // Handle controller change (new service worker activated)
    navigator.serviceWorker.addEventListener('controllerchange', () => {
      console.log('[PWA] New Service Worker activated');
    });
  });
}

// Handle install prompt for PWA
let deferredPrompt;

window.addEventListener('beforeinstallprompt', (e) => {
  console.log('[PWA] Install prompt available');
  // Prevent the mini-infobar from appearing on mobile
  e.preventDefault();
  // Stash the event so it can be triggered later
  deferredPrompt = e;
  
  // Optionally, show your own install button
  // You can create a custom UI element to trigger the install
  showInstallPromotion();
});

window.addEventListener('appinstalled', () => {
  console.log('[PWA] App installed successfully');
  deferredPrompt = null;
});

function showInstallPromotion() {
  // You can implement a custom install button here
  // For now, we'll just log that it's available
  console.log('[PWA] App can be installed');
  
  // Example: Create an install button dynamically
  // const installButton = document.createElement('button');
  // installButton.textContent = 'Install App';
  // installButton.onclick = async () => {
  //   if (deferredPrompt) {
  //     deferredPrompt.prompt();
  //     const { outcome } = await deferredPrompt.userChoice;
  //     console.log(`User response: ${outcome}`);
  //     deferredPrompt = null;
  //   }
  // };
  // document.body.appendChild(installButton);
}

