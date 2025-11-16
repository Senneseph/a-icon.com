# End-to-End Tests for a-icon.com

This directory contains Playwright-based end-to-end tests for the a-icon.com favicon generator application.

## Setup

1. Install dependencies:
```bash
cd e2e
npm install
npx playwright install
```

## Running Tests

### Test against production (https://a-icon.com)
```bash
npm run test:production
```

### Test against local development
```bash
# Make sure both API and Web are running locally first
# API on http://localhost:3000
# Web on http://localhost:4200

npm run test:local
```

### Run tests with UI mode (interactive)
```bash
npm run test:ui
```

### Run tests in headed mode (see browser)
```bash
npm run test:headed
```

### Debug tests
```bash
npm run test:debug
```

### View test report
```bash
npm run report
```

## Test Coverage

The test suite covers:

1. **Home Page**: Verifies the home page loads correctly
2. **Upload Page**: Tests navigation to upload page
3. **Image Upload**: Tests uploading an image and creating a favicon
4. **Directory Page**: Verifies the directory page displays favicons
5. **Favicon Previews**: Checks that favicon preview images load correctly
6. **API Health**: Tests the API health endpoint
7. **API Directory**: Tests the API directory endpoint
8. **Detail View**: Verifies favicon detail page links work

## Environment Variables

- `BASE_URL`: The base URL of the web application (default: https://a-icon.com)
- `API_URL`: The base URL of the API (default: https://a-icon.com/api)

## CI/CD Integration

These tests can be integrated into your CI/CD pipeline. The tests are configured to:
- Run in parallel on CI
- Retry failed tests 2 times on CI
- Generate HTML reports
- Take screenshots on failure
- Capture traces on first retry

## Troubleshooting

### Tests fail with "Connection refused"
- Make sure the application is running at the specified BASE_URL
- Check that the API is accessible at the specified API_URL

### Image loading tests fail
- Verify that the storage controller is properly serving images
- Check that the `/api/storage/sources/:faviconId/original` endpoint is working
- Ensure CORS is configured correctly if testing cross-origin

### Upload tests fail
- Verify that the upload endpoint accepts multipart/form-data
- Check that file size limits are not exceeded
- Ensure the API has write permissions to the storage directory

