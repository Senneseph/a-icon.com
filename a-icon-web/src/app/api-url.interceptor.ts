import { HttpInterceptorFn } from '@angular/common/http';
import { inject, PLATFORM_ID } from '@angular/core';
import { isPlatformServer } from '@angular/common';

/**
 * HTTP Interceptor that modifies API URLs for server-side rendering.
 * When running on the server (SSR), it replaces relative API URLs with
 * the internal Docker network URL so the server can communicate with the API.
 */
export const apiUrlInterceptor: HttpInterceptorFn = (req, next) => {
  const platformId = inject(PLATFORM_ID);
  const isServer = isPlatformServer(platformId);

  console.log(`[API Interceptor] ${isServer ? 'SERVER' : 'BROWSER'} - Request to:`, req.url);

  // Only modify requests when running on the server (SSR)
  if (isServer) {
    // Get the SSR API URL from environment variable
    const ssrApiUrl = (typeof process !== 'undefined' && process.env?.['API_URL_SSR']) || 'http://api:3000';

    // Check if this is a relative API request
    if (req.url.startsWith('/api/')) {
      // Replace relative URL with absolute SSR URL
      const modifiedUrl = `${ssrApiUrl}${req.url}`;
      console.log(`[API Interceptor] SERVER - Rewriting to:`, modifiedUrl);
      const modifiedReq = req.clone({
        url: modifiedUrl,
      });
      return next(modifiedReq);
    }
  }

  // For browser requests or non-API requests, pass through unchanged
  return next(req);
};

