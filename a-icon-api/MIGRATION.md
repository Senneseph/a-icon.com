# Asset Naming Migration

## Overview

This migration updates the naming scheme for favicon assets to include the domain name in the filename.

## New Naming Scheme

**Old Format:**
```
favicons/{slug}/{size}.{extension}
favicons/{slug}/multi.ico
```

**New Format:**
```
favicons/{slug}/{size}-{domain}.{extension}
favicons/{slug}/favicon-{domain}.ico
```

**Examples:**
- Old: `favicons/abc123/16x16.png`
- New: `favicons/abc123/16x16-a-icon.com.png`

- Old: `favicons/abc123/multi.ico`
- New: `favicons/abc123/favicon-a-icon.com.ico`

## Running the Migration

### Prerequisites

1. Stop the API server to prevent conflicts
2. Backup your database and storage directory

### Steps

1. Navigate to the API directory:
   ```bash
   cd a-icon-api
   ```

2. Run the migration script:
   ```bash
   npm run migrate:asset-names
   ```

3. The script will:
   - Read all favicons from the database
   - For each favicon, get the target domain (defaults to "a-icon.com")
   - Rename physical files in the storage directory
   - Update the `storage_key` in the database

4. Review the migration summary output

### Migration Output

The script provides detailed output:
- ✓ Successfully migrated assets
- ⚠ Skipped assets (already migrated or conflicts)
- ✗ Errors encountered

### Rollback

If you need to rollback:
1. Restore your database backup
2. Restore your storage directory backup

## Changes to Code

### Backend Changes

1. **favicon.service.ts**: Updated `generateAssets()` to use new naming scheme
2. **database.service.ts**: Added `getFaviconById()` method
3. **Migration script**: Created `src/scripts/migrate-asset-names.ts`

### Frontend Changes

1. **upload.component.html**: Added domain name input field
2. **upload.component.ts**: 
   - Added `domainName` property (default: "a-icon.com")
   - Updated `uploadImage()` to send domain to API
3. **favicon-detail.component.ts**: 
   - Added `getAssetFilename()` method
   - Fixed `FaviconAsset.size` type to string

## Testing

After migration:

1. Upload a new favicon with a custom domain
2. Verify the generated assets have the correct naming
3. Test downloading assets from the detail page
4. Verify existing favicons still work correctly

## Notes

- The domain field is **mandatory** in the upload form
- Default domain is "a-icon.com"
- The migration is idempotent - running it multiple times is safe
- Assets already using the new naming scheme are skipped

