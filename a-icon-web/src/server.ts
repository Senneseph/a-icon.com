import {
  AngularNodeAppEngine,
  createNodeRequestHandler,
  isMainModule,
  writeResponseToNodeResponse,
} from '@angular/ssr/node';
import express from 'express';
import { join } from 'node:path';

const browserDistFolder = join(import.meta.dirname, '../browser');

const app = express();
const angularApp = new AngularNodeAppEngine();

/**
 * Proxy API requests to the backend API server
 * Note: We bypass this proxy for file uploads by making direct requests from the browser
 */
app.use('/api', async (req, res, next) => {
  const apiUrl = process.env['API_URL_SSR'] || 'http://api:3000';
  const targetUrl = `${apiUrl}${req.originalUrl}`;

  console.log(`[API Proxy] ${req.method} ${req.originalUrl} -> ${targetUrl}`);

  try {
    // For multipart/form-data or other non-JSON requests, we need to forward the raw body
    // However, Express doesn't parse the body by default, so we need to collect it
    const chunks: Buffer[] = [];
    req.on('data', (chunk) => chunks.push(chunk));
    await new Promise((resolve) => req.on('end', resolve));
    const rawBody = Buffer.concat(chunks);

    const response = await fetch(targetUrl, {
      method: req.method,
      headers: req.headers as HeadersInit,
      body: req.method !== 'GET' && req.method !== 'HEAD' ? rawBody : undefined,
    });

    console.log(`[API Proxy] Response: ${response.status}`);

    // Copy response headers
    response.headers.forEach((value, key) => {
      res.setHeader(key, value);
    });

    // Set status and send body
    res.status(response.status);
    const body = await response.text();
    res.send(body);
  } catch (error) {
    console.error('[API Proxy] Error:', error);
    res.status(502).json({ error: 'Bad Gateway' });
  }
});

/**
 * Serve static files from /browser
 */
app.use(
  express.static(browserDistFolder, {
    maxAge: '1y',
    index: false,
    redirect: false,
  }),
);

/**
 * Handle all other requests by rendering the Angular application.
 */
app.use((req, res, next) => {
  angularApp
    .handle(req)
    .then((response) =>
      response ? writeResponseToNodeResponse(response, res) : next(),
    )
    .catch(next);
});

/**
 * Start the server if this module is the main entry point, or it is ran via PM2.
 * The server listens on the port defined by the `PORT` environment variable, or defaults to 4000.
 */
if (isMainModule(import.meta.url) || process.env['pm_id']) {
  const port = process.env['PORT'] || 4000;
  app.listen(port, (error) => {
    if (error) {
      throw error;
    }

    console.log(`Node Express server listening on http://localhost:${port}`);
  });
}

/**
 * Request handler used by the Angular CLI (for dev-server and during build) or Firebase Cloud Functions.
 */
export const reqHandler = createNodeRequestHandler(app);
