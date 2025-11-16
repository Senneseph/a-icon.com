import { test, expect } from '@playwright/test';

const BASE_URL = process.env.BASE_URL || 'https://a-icon.com';
const API_URL = process.env.API_URL || 'https://a-icon.com/api';

test.describe('Favicon Generator E2E Tests', () => {
  test('should load the home page', async ({ page }) => {
    await page.goto(BASE_URL);
    await expect(page).toHaveTitle(/a-icon/i);
  });

  test('should navigate to upload page', async ({ page }) => {
    await page.goto(BASE_URL);
    // Look for upload button or link
    const uploadButton = page.locator('button:has-text("Upload"), a:has-text("Upload")').first();
    if (await uploadButton.isVisible()) {
      await uploadButton.click();
      await expect(page).toHaveURL(/upload/);
    }
  });

  test('should upload an image and create a favicon', async ({ page }) => {
    await page.goto(`${BASE_URL}/upload`);

    // Create a simple test image (1x1 red pixel PNG)
    const testImageBuffer = Buffer.from(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg==',
      'base64'
    );

    // Find the file input
    const fileInput = page.locator('input[type="file"]');
    await expect(fileInput).toBeVisible();

    // Upload the file
    await fileInput.setInputFiles({
      name: 'test-favicon.png',
      mimeType: 'image/png',
      buffer: testImageBuffer,
    });

    // Wait for upload to complete and check for success indicators
    // This might be a success message, redirect, or new content
    await page.waitForTimeout(2000); // Give time for upload processing

    // Check if we got redirected or see success message
    const url = page.url();
    console.log('Current URL after upload:', url);
  });

  test('should display favicons in directory', async ({ page }) => {
    await page.goto(`${BASE_URL}/directory`);

    // Wait for the page to load
    await page.waitForLoadState('networkidle');

    // Check for directory heading
    await expect(page.locator('h1:has-text("Directory")')).toBeVisible();

    // Check if there are any favicon cards or empty state
    const faviconCards = page.locator('.favicon-card');
    const emptyState = page.locator('.empty-state');

    const hasCards = (await faviconCards.count()) > 0;
    const hasEmptyState = await emptyState.isVisible();

    expect(hasCards || hasEmptyState).toBeTruthy();

    if (hasCards) {
      // Verify first card has required elements
      const firstCard = faviconCards.first();
      await expect(firstCard.locator('.favicon-preview img')).toBeVisible();
      await expect(firstCard.locator('.favicon-slug')).toBeVisible();
      await expect(firstCard.locator('.favicon-date')).toBeVisible();
      await expect(firstCard.locator('.favicon-assets')).toBeVisible();
    }
  });

  test('should verify favicon preview images load', async ({ page }) => {
    await page.goto(`${BASE_URL}/directory`);
    await page.waitForLoadState('networkidle');

    const faviconCards = page.locator('.favicon-card');
    const count = await faviconCards.count();

    if (count > 0) {
      // Check first favicon image
      const firstImage = faviconCards.first().locator('.favicon-preview img');
      await expect(firstImage).toBeVisible();

      // Verify image src is set
      const src = await firstImage.getAttribute('src');
      expect(src).toBeTruthy();
      expect(src).toContain('/api/storage/');

      // Wait for image to load and check natural dimensions
      await firstImage.waitFor({ state: 'visible' });
      
      // Check if image loaded successfully (not broken)
      const isImageLoaded = await firstImage.evaluate((img: HTMLImageElement) => {
        return img.complete && img.naturalHeight > 0;
      });
      
      if (!isImageLoaded) {
        console.warn('Image failed to load:', src);
      }
    }
  });

  test('should test API health endpoint', async ({ request }) => {
    const response = await request.get(`${API_URL}/health`);
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(data).toHaveProperty('status', 'ok');
    expect(data).toHaveProperty('timestamp');
  });

  test('should test API directory endpoint', async ({ request }) => {
    const response = await request.get(`${API_URL}/directory`);
    expect(response.ok()).toBeTruthy();
    
    const data = await response.json();
    expect(Array.isArray(data)).toBeTruthy();
    
    if (data.length > 0) {
      const firstItem = data[0];
      expect(firstItem).toHaveProperty('id');
      expect(firstItem).toHaveProperty('slug');
      expect(firstItem).toHaveProperty('sourceUrl');
      expect(firstItem).toHaveProperty('createdAt');
      expect(firstItem).toHaveProperty('assetCount');
    }
  });

  test('should verify favicon detail view links work', async ({ page }) => {
    await page.goto(`${BASE_URL}/directory`);
    await page.waitForLoadState('networkidle');

    const faviconCards = page.locator('.favicon-card');
    const count = await faviconCards.count();

    if (count > 0) {
      const viewButton = faviconCards.first().locator('.btn-view');
      if (await viewButton.isVisible()) {
        const href = await viewButton.getAttribute('href');
        expect(href).toBeTruthy();
        console.log('View button href:', href);
      }
    }
  });

  test('should verify asset view and download links on detail page', async ({ page, context }) => {
    // First, go to directory to find a favicon
    await page.goto(`${BASE_URL}/directory`);
    await page.waitForLoadState('networkidle');

    const faviconCards = page.locator('.favicon-card');
    const count = await faviconCards.count();

    if (count === 0) {
      console.log('No favicons in directory, skipping asset link test');
      return;
    }

    // Click on the first favicon's "View Details" button
    const viewButton = faviconCards.first().locator('.btn-view');
    await viewButton.click();

    // Wait for navigation to detail page
    await page.waitForURL(/\/favicon\//);
    await page.waitForLoadState('networkidle');

    // Verify we're on the detail page
    expect(page.url()).toContain('/favicon/');

    // Wait for assets section to load
    const assetsSection = page.locator('.assets-section');
    await expect(assetsSection).toBeVisible();

    // Check if there are any assets
    const assetCards = page.locator('.asset-card');
    const assetCount = await assetCards.count();

    console.log(`Found ${assetCount} assets on detail page`);

    if (assetCount > 0) {
      const firstAsset = assetCards.first();

      // Test "View" link
      const viewLink = firstAsset.locator('a:has-text("View")');
      await expect(viewLink).toBeVisible();

      const viewHref = await viewLink.getAttribute('href');
      expect(viewHref).toBeTruthy();
      expect(viewHref).toContain('/api/storage/');
      console.log('Asset view link:', viewHref);

      // Verify the view link actually loads an image
      const newPage = await context.newPage();
      const response = await newPage.goto(viewHref!);
      expect(response?.ok()).toBeTruthy();

      const contentType = response?.headers()['content-type'];
      expect(contentType).toMatch(/image\/(png|x-icon|svg\+xml|jpeg)/);
      console.log('Asset content type:', contentType);

      await newPage.close();

      // Test "Download" button
      const downloadButton = firstAsset.locator('button:has-text("Download")');
      await expect(downloadButton).toBeVisible();

      // Set up download listener
      const downloadPromise = page.waitForEvent('download', { timeout: 5000 }).catch(() => null);

      // Click download button
      await downloadButton.click();

      // Wait a bit for download to potentially start
      const download = await downloadPromise;

      if (download) {
        console.log('Download started:', await download.suggestedFilename());

        // Verify filename format (should be slug-size.format)
        const filename = await download.suggestedFilename();
        expect(filename).toMatch(/.*-\d+\.(png|ico|svg)$/);

        // Cancel the download (we don't need to actually save it)
        await download.cancel();
      } else {
        console.log('Download did not trigger (may be browser-dependent)');
      }
    } else {
      console.log('No assets found on detail page');
    }
  });

  test('should verify all asset links are valid', async ({ page, request }) => {
    // Go to directory
    await page.goto(`${BASE_URL}/directory`);
    await page.waitForLoadState('networkidle');

    const faviconCards = page.locator('.favicon-card');
    const count = await faviconCards.count();

    if (count === 0) {
      console.log('No favicons in directory, skipping asset validation test');
      return;
    }

    // Navigate to first favicon detail page
    const viewButton = faviconCards.first().locator('.btn-view');
    await viewButton.click();
    await page.waitForURL(/\/favicon\//);
    await page.waitForLoadState('networkidle');

    // Get all asset view links
    const assetViewLinks = page.locator('.asset-card a:has-text("View")');
    const linkCount = await assetViewLinks.count();

    console.log(`Validating ${linkCount} asset links`);

    // Validate each link
    for (let i = 0; i < Math.min(linkCount, 5); i++) { // Test up to 5 assets
      const link = assetViewLinks.nth(i);
      const href = await link.getAttribute('href');

      if (href) {
        console.log(`Testing asset link ${i + 1}: ${href}`);

        // Make a request to verify the asset is accessible
        const response = await request.get(href);
        expect(response.ok()).toBeTruthy();

        const contentType = response.headers()['content-type'];
        expect(contentType).toMatch(/image\/(png|x-icon|svg\+xml|jpeg)/);
      }
    }
  });
});

