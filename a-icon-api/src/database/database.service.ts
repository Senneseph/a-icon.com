import { Injectable, OnModuleInit } from '@nestjs/common';
import Database from 'better-sqlite3';
import { join } from 'path';

export interface Favicon {
  id: string;
  slug: string;
  title: string | null;
  target_domain: string | null;
  published_url: string;
  canonical_svg_key: string | null;
  source_type: 'UPLOAD' | 'CANVAS';
  source_original_mime: string | null;
  source_hash: string | null; // MD5 hash of source image for duplicate detection
  source_size: number | null; // File size in bytes for duplicate detection
  is_published: number; // SQLite uses 0/1 for boolean
  created_at: string;
  updated_at: string;
  generated_at: string | null;
  generation_status: 'PENDING' | 'SUCCESS' | 'FAILED';
  generation_error: string | null;
  metadata: string | null; // Secret metadata embedded in images
  has_steganography: number; // 0/1 - whether steganography was applied
}

export interface FaviconAsset {
  id: string;
  favicon_id: string;
  type: string; // 'ICO', 'PNG', 'SVG'
  size: string | null; // '16x16', '192x192', 'MULTI', etc.
  format: string; // '.ico', '.png', '.svg'
  storage_key: string;
  mime_type: string;
  created_at: string;
}

@Injectable()
export class DatabaseService implements OnModuleInit {
  private db: Database.Database;

  onModuleInit() {
    const dbPath = process.env.DB_PATH || join(process.cwd(), 'data', 'a-icon.db');
    this.db = new Database(dbPath);
    this.initSchema();
  }

  private initSchema() {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS favicons (
        id TEXT PRIMARY KEY,
        slug TEXT UNIQUE NOT NULL,
        title TEXT,
        target_domain TEXT,
        published_url TEXT NOT NULL,
        canonical_svg_key TEXT,
        source_type TEXT NOT NULL CHECK(source_type IN ('UPLOAD', 'CANVAS')),
        source_original_mime TEXT,
        source_hash TEXT,
        source_size INTEGER,
        is_published INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        generated_at TEXT,
        generation_status TEXT NOT NULL CHECK(generation_status IN ('PENDING', 'SUCCESS', 'FAILED')),
        generation_error TEXT,
        metadata TEXT,
        has_steganography INTEGER NOT NULL DEFAULT 0
      );

      CREATE INDEX IF NOT EXISTS idx_favicons_created_at ON favicons(created_at);
      CREATE INDEX IF NOT EXISTS idx_favicons_published_url ON favicons(published_url);
      CREATE INDEX IF NOT EXISTS idx_favicons_target_domain ON favicons(target_domain);
      CREATE INDEX IF NOT EXISTS idx_favicons_is_published ON favicons(is_published);

      CREATE TABLE IF NOT EXISTS favicon_assets (
        id TEXT PRIMARY KEY,
        favicon_id TEXT NOT NULL,
        type TEXT NOT NULL,
        size TEXT,
        format TEXT NOT NULL,
        storage_key TEXT NOT NULL,
        mime_type TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (favicon_id) REFERENCES favicons(id) ON DELETE CASCADE
      );

      CREATE INDEX IF NOT EXISTS idx_favicon_assets_favicon_id ON favicon_assets(favicon_id);
    `);

    // Add source_hash and source_size columns if they don't exist (migration)
    const tableInfo = this.db.pragma('table_info(favicons)') as Array<{ name: string }>;
    const hasSourceHash = tableInfo.some((col) => col.name === 'source_hash');
    const hasSourceSize = tableInfo.some((col) => col.name === 'source_size');

    if (!hasSourceHash) {
      console.log('Adding source_hash column to favicons table...');
      this.db.exec('ALTER TABLE favicons ADD COLUMN source_hash TEXT');
    }

    if (!hasSourceSize) {
      console.log('Adding source_size column to favicons table...');
      this.db.exec('ALTER TABLE favicons ADD COLUMN source_size INTEGER');
    }

    // Always create/ensure the index exists (safe to run multiple times)
    console.log('Ensuring index on source_hash and source_size exists...');
    this.db.exec('CREATE INDEX IF NOT EXISTS idx_favicons_hash_size ON favicons(source_hash, source_size)');
  }

  getDb(): Database.Database {
    return this.db;
  }

  // Favicon CRUD
  insertFavicon(favicon: Favicon): void {
    const stmt = this.db.prepare(`
      INSERT INTO favicons (
        id, slug, title, target_domain, published_url, canonical_svg_key,
        source_type, source_original_mime, source_hash, source_size, is_published, created_at, updated_at,
        generated_at, generation_status, generation_error, metadata, has_steganography
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `);
    stmt.run(
      favicon.id,
      favicon.slug,
      favicon.title,
      favicon.target_domain,
      favicon.published_url,
      favicon.canonical_svg_key,
      favicon.source_type,
      favicon.source_original_mime,
      favicon.source_hash,
      favicon.source_size,
      favicon.is_published,
      favicon.created_at,
      favicon.updated_at,
      favicon.generated_at,
      favicon.generation_status,
      favicon.generation_error,
      favicon.metadata,
      favicon.has_steganography,
    );
  }

  getFaviconBySlug(slug: string): Favicon | undefined {
    const stmt = this.db.prepare('SELECT * FROM favicons WHERE slug = ?');
    return stmt.get(slug) as Favicon | undefined;
  }

  getFaviconById(id: string): Favicon | undefined {
    const stmt = this.db.prepare('SELECT * FROM favicons WHERE id = ?');
    return stmt.get(id) as Favicon | undefined;
  }

  findFaviconByHash(hash: string, size: number): Favicon | undefined {
    const stmt = this.db.prepare(
      'SELECT * FROM favicons WHERE source_hash = ? AND source_size = ? LIMIT 1'
    );
    return stmt.get(hash, size) as Favicon | undefined;
  }

  updateFaviconStatus(
    id: string,
    status: 'PENDING' | 'SUCCESS' | 'FAILED',
    error: string | null,
    generatedAt: string | null,
  ): void {
    const stmt = this.db.prepare(`
      UPDATE favicons
      SET generation_status = ?, generation_error = ?, generated_at = ?, updated_at = ?
      WHERE id = ?
    `);
    stmt.run(status, error, generatedAt, new Date().toISOString(), id);
  }

  // FaviconAsset CRUD
  insertFaviconAsset(asset: FaviconAsset): void {
    const stmt = this.db.prepare(`
      INSERT INTO favicon_assets (id, favicon_id, type, size, format, storage_key, mime_type, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?)
    `);
    stmt.run(
      asset.id,
      asset.favicon_id,
      asset.type,
      asset.size,
      asset.format,
      asset.storage_key,
      asset.mime_type,
      asset.created_at,
    );
  }

  getAssetsByFaviconId(faviconId: string): FaviconAsset[] {
    const stmt = this.db.prepare('SELECT * FROM favicon_assets WHERE favicon_id = ?');
    return stmt.all(faviconId) as FaviconAsset[];
  }
}

