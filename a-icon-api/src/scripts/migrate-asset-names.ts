import { DatabaseService } from '../database/database.service';
import { StorageService } from '../storage/storage.service';
import { join } from 'path';
import { existsSync, renameSync } from 'fs';

/**
 * Migration script to rename existing favicon assets to the new naming scheme:
 * Old: favicons/{slug}/{size}.{ext}
 * New: favicons/{slug}/{size}-{domain}.{ext}
 * 
 * For MULTI size ICO files: favicon-{domain}.ico
 */
async function migrateAssetNames() {
  console.log('Starting asset name migration...');

  // Initialize services
  const dbService = new DatabaseService();
  await dbService.onModuleInit();

  const storageService = new StorageService();
  await storageService.onModuleInit();

  const storageRoot = process.env.STORAGE_ROOT || join(process.cwd(), 'data', 'storage');

  // Get all favicons
  const db = (dbService as any).db;
  const favicons = db.prepare('SELECT * FROM favicons').all();

  console.log(`Found ${favicons.length} favicons to process`);

  let totalAssets = 0;
  let migratedAssets = 0;
  let skippedAssets = 0;
  let errorAssets = 0;

  for (const favicon of favicons) {
    const domain = favicon.target_domain || 'a-icon.com';
    const assets = dbService.getAssetsByFaviconId(favicon.id);

    console.log(`\nProcessing favicon ${favicon.slug} (${assets.length} assets) with domain: ${domain}`);

    for (const asset of assets) {
      totalAssets++;
      const oldStorageKey = asset.storage_key;

      // Parse the old storage key to extract size and format
      // Old format: favicons/{slug}/{size}.{ext} or favicons/{slug}/multi.{ext}
      const parts = oldStorageKey.split('/');
      const oldFilename = parts[parts.length - 1];

      // Check if already migrated (contains domain in filename)
      if (oldFilename.includes(domain)) {
        console.log(`  ✓ Already migrated: ${oldFilename}`);
        skippedAssets++;
        continue;
      }

      // Generate new filename based on naming scheme
      let newFilename: string;
      if (asset.size === 'MULTI') {
        newFilename = `favicon-${domain}${asset.format}`;
      } else {
        newFilename = `${asset.size}-${domain}${asset.format}`;
      }

      const newStorageKey = `favicons/${favicon.slug}/${newFilename}`;

      // Check if old file exists
      const oldPath = join(storageRoot, oldStorageKey);
      const newPath = join(storageRoot, newStorageKey);

      if (!existsSync(oldPath)) {
        console.log(`  ⚠ File not found: ${oldPath}`);
        errorAssets++;
        continue;
      }

      // Check if new file already exists
      if (existsSync(newPath)) {
        console.log(`  ⚠ New file already exists: ${newPath}`);
        skippedAssets++;
        continue;
      }

      try {
        // Rename the file
        renameSync(oldPath, newPath);

        // Update database
        const updateStmt = db.prepare('UPDATE favicon_assets SET storage_key = ? WHERE id = ?');
        updateStmt.run(newStorageKey, asset.id);

        console.log(`  ✓ Migrated: ${oldFilename} → ${newFilename}`);
        migratedAssets++;
      } catch (error) {
        console.error(`  ✗ Error migrating ${oldFilename}:`, error);
        errorAssets++;
      }
    }
  }

  console.log('\n=== Migration Summary ===');
  console.log(`Total assets: ${totalAssets}`);
  console.log(`Migrated: ${migratedAssets}`);
  console.log(`Skipped: ${skippedAssets}`);
  console.log(`Errors: ${errorAssets}`);
  console.log('Migration complete!');
}

// Run the migration
migrateAssetNames().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});

