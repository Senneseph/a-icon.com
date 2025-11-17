import Database from 'better-sqlite3';
import { join } from 'path';

/**
 * Migration script to add source_hash and source_size columns to favicons table
 * These fields are used for duplicate detection
 */
function migrate() {
  const dbPath = process.env.DB_PATH || join(process.cwd(), 'data', 'a-icon.db');
  console.log(`Opening database at: ${dbPath}`);
  
  const db = new Database(dbPath);
  
  try {
    // Check if columns already exist
    const tableInfo = db.pragma('table_info(favicons)') as Array<{ name: string }>;
    const hasSourceHash = tableInfo.some((col) => col.name === 'source_hash');
    const hasSourceSize = tableInfo.some((col) => col.name === 'source_size');
    
    if (hasSourceHash && hasSourceSize) {
      console.log('✓ Columns source_hash and source_size already exist');
      return;
    }
    
    // Add source_hash column (MD5 hash of source image)
    if (!hasSourceHash) {
      console.log('Adding source_hash column...');
      db.exec(`
        ALTER TABLE favicons 
        ADD COLUMN source_hash TEXT;
      `);
      console.log('✓ Added source_hash column');
    }
    
    // Add source_size column (file size in bytes)
    if (!hasSourceSize) {
      console.log('Adding source_size column...');
      db.exec(`
        ALTER TABLE favicons 
        ADD COLUMN source_size INTEGER;
      `);
      console.log('✓ Added source_size column');
    }
    
    // Create index for faster duplicate lookups
    console.log('Creating index for duplicate detection...');
    db.exec(`
      CREATE INDEX IF NOT EXISTS idx_favicons_hash_size 
      ON favicons(source_hash, source_size);
    `);
    console.log('✓ Created index idx_favicons_hash_size');
    
    console.log('\n✅ Migration complete!');
  } catch (error) {
    console.error('❌ Migration failed:', error);
    throw error;
  } finally {
    db.close();
  }
}

// Run migration
migrate();

