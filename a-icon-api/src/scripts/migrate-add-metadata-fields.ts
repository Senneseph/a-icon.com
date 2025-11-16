import Database from 'better-sqlite3';
import { join } from 'path';

/**
 * Migration script to add metadata and has_steganography fields to the favicons table
 */
async function migrateAddMetadataFields() {
  console.log('Starting metadata fields migration...');

  const dbPath = process.env.DB_PATH || join(process.cwd(), 'data', 'a-icon.db');
  const db = new Database(dbPath);

  try {
    // Check if columns already exist
    const tableInfo = db.prepare("PRAGMA table_info(favicons)").all() as any[];
    const hasMetadata = tableInfo.some((col) => col.name === 'metadata');
    const hasSteganography = tableInfo.some((col) => col.name === 'has_steganography');

    if (hasMetadata && hasSteganography) {
      console.log('✓ Metadata fields already exist. No migration needed.');
      db.close();
      return;
    }

    console.log('Adding metadata fields to favicons table...');

    // SQLite doesn't support adding multiple columns in one statement
    if (!hasMetadata) {
      db.exec('ALTER TABLE favicons ADD COLUMN metadata TEXT');
      console.log('✓ Added metadata column');
    }

    if (!hasSteganography) {
      db.exec('ALTER TABLE favicons ADD COLUMN has_steganography INTEGER NOT NULL DEFAULT 0');
      console.log('✓ Added has_steganography column');
    }

    console.log('✅ Migration complete!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    db.close();
  }
}

// Run the migration
migrateAddMetadataFields().catch((error) => {
  console.error('Migration failed:', error);
  process.exit(1);
});

