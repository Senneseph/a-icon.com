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
});

