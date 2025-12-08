use crate::error::HandlerError;
use crate::db_err;
use crate::models::{Favicon, FaviconAsset, SourceType, GenerationStatus, AssetType, DirectoryItem};
use rusqlite::{Connection, params, OptionalExtension};
use chrono::{DateTime, Utc};
use std::path::Path;

pub struct Database {
    conn: Connection,
}

impl Database {
    pub fn new<P: AsRef<Path>>(db_path: P) -> Result<Self, HandlerError> {
        let conn = db_err!(Connection::open(db_path))?;

        let db = Database { conn };
        db.init_schema()?;
        Ok(db)
    }

    fn init_schema(&self) -> Result<(), HandlerError> {
        db_err!(self.conn.execute_batch(
            r#"
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
            CREATE INDEX IF NOT EXISTS idx_favicons_source_hash ON favicons(source_hash);

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
            "#
        ))?;
        Ok(())
    }

    pub fn get_favicon_by_id(&self, id: &str) -> Result<Option<Favicon>, HandlerError> {
        let mut stmt = db_err!(self.conn.prepare(
            "SELECT id, slug, title, target_domain, published_url, canonical_svg_key,
                    source_type, source_original_mime, source_hash, source_size, is_published,
                    created_at, updated_at, generated_at, generation_status, generation_error,
                    metadata, has_steganography
             FROM favicons WHERE id = ?"
        ))?;

        let favicon = db_err!(stmt.query_row([id], |row| {
            Ok(Favicon {
                id: row.get(0)?,
                slug: row.get(1)?,
                title: row.get(2)?,
                target_domain: row.get(3)?,
                published_url: row.get(4)?,
                canonical_svg_key: row.get(5)?,
                source_type: SourceType::from_str(&row.get::<_, String>(6)?).unwrap(),
                source_original_mime: row.get(7)?,
                source_hash: row.get(8)?,
                source_size: row.get(9)?,
                is_published: row.get::<_, i32>(10)? == 1,
                created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(11)?)
                    .unwrap().with_timezone(&Utc),
                updated_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(12)?)
                    .unwrap().with_timezone(&Utc),
                generated_at: row.get::<_, Option<String>>(13)?
                    .map(|s| DateTime::parse_from_rfc3339(&s).unwrap().with_timezone(&Utc)),
                generation_status: GenerationStatus::from_str(&row.get::<_, String>(14)?).unwrap(),
                generation_error: row.get(15)?,
                metadata: row.get(16)?,
                has_steganography: row.get::<_, i32>(17)? == 1,
            })
        }).optional())?;

        Ok(favicon)
    }

    pub fn get_favicon_by_slug(&self, slug: &str) -> Result<Option<Favicon>, HandlerError> {
        let mut stmt = db_err!(self.conn.prepare(
            "SELECT id, slug, title, target_domain, published_url, canonical_svg_key,
                    source_type, source_original_mime, source_hash, source_size, is_published,
                    created_at, updated_at, generated_at, generation_status, generation_error,
                    metadata, has_steganography
             FROM favicons WHERE slug = ?"
        ))?;

        let favicon = db_err!(stmt.query_row([slug], |row| {
            Ok(Favicon {
                id: row.get(0)?,
                slug: row.get(1)?,
                title: row.get(2)?,
                target_domain: row.get(3)?,
                published_url: row.get(4)?,
                canonical_svg_key: row.get(5)?,
                source_type: SourceType::from_str(&row.get::<_, String>(6)?).unwrap(),
                source_original_mime: row.get(7)?,
                source_hash: row.get(8)?,
                source_size: row.get(9)?,
                is_published: row.get::<_, i32>(10)? == 1,
                created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(11)?)
                    .unwrap().with_timezone(&Utc),
                updated_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(12)?)
                    .unwrap().with_timezone(&Utc),
                generated_at: row.get::<_, Option<String>>(13)?
                    .map(|s| DateTime::parse_from_rfc3339(&s).unwrap().with_timezone(&Utc)),
                generation_status: GenerationStatus::from_str(&row.get::<_, String>(14)?).unwrap(),
                generation_error: row.get(15)?,
                metadata: row.get(16)?,
                has_steganography: row.get::<_, i32>(17)? == 1,
            })
        }).optional())?;

        Ok(favicon)
    }

    pub fn find_duplicate(&self, hash: &str, size: i64) -> Result<Option<Favicon>, HandlerError> {
        let mut stmt = db_err!(self.conn.prepare(
            "SELECT id FROM favicons WHERE source_hash = ? AND source_size = ? LIMIT 1"
        ))?;

        let id: Option<String> = db_err!(stmt.query_row(params![hash, size], |row| row.get(0))
            .optional())?;

        match id {
            Some(id) => self.get_favicon_by_id(&id),
            None => Ok(None),
        }
    }

    pub fn insert_favicon(&self, favicon: &Favicon) -> Result<(), HandlerError> {
        db_err!(self.conn.execute(
            "INSERT INTO favicons (
                id, slug, title, target_domain, published_url, canonical_svg_key,
                source_type, source_original_mime, source_hash, source_size, is_published,
                created_at, updated_at, generated_at, generation_status, generation_error,
                metadata, has_steganography
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params![
                favicon.id,
                favicon.slug,
                favicon.title,
                favicon.target_domain,
                favicon.published_url,
                favicon.canonical_svg_key,
                favicon.source_type.as_str(),
                favicon.source_original_mime,
                favicon.source_hash,
                favicon.source_size,
                if favicon.is_published { 1 } else { 0 },
                favicon.created_at.to_rfc3339(),
                favicon.updated_at.to_rfc3339(),
                favicon.generated_at.map(|dt| dt.to_rfc3339()),
                favicon.generation_status.as_str(),
                favicon.generation_error,
                favicon.metadata,
                if favicon.has_steganography { 1 } else { 0 },
            ]
        ))?;
        Ok(())
    }

    pub fn update_favicon(&self, favicon: &Favicon) -> Result<(), HandlerError> {
        db_err!(self.conn.execute(
            "UPDATE favicons SET
                slug = ?, title = ?, target_domain = ?, published_url = ?, canonical_svg_key = ?,
                source_type = ?, source_original_mime = ?, source_hash = ?, source_size = ?,
                is_published = ?, updated_at = ?, generated_at = ?, generation_status = ?,
                generation_error = ?, metadata = ?, has_steganography = ?
             WHERE id = ?",
            params![
                favicon.slug,
                favicon.title,
                favicon.target_domain,
                favicon.published_url,
                favicon.canonical_svg_key,
                favicon.source_type.as_str(),
                favicon.source_original_mime,
                favicon.source_hash,
                favicon.source_size,
                if favicon.is_published { 1 } else { 0 },
                favicon.updated_at.to_rfc3339(),
                favicon.generated_at.map(|dt| dt.to_rfc3339()),
                favicon.generation_status.as_str(),
                favicon.generation_error,
                favicon.metadata,
                if favicon.has_steganography { 1 } else { 0 },
                favicon.id,
            ]
        ))?;
        Ok(())
    }

    pub fn delete_favicon(&self, id: &str) -> Result<(), HandlerError> {
        db_err!(self.conn.execute("DELETE FROM favicons WHERE id = ?", [id]))?;
        Ok(())
    }

    pub fn get_assets_by_favicon_id(&self, favicon_id: &str) -> Result<Vec<FaviconAsset>, HandlerError> {
        let mut stmt = db_err!(self.conn.prepare(
            "SELECT id, favicon_id, type, size, format, storage_key, mime_type, created_at
             FROM favicon_assets WHERE favicon_id = ?"
        ))?;

        let assets = db_err!(db_err!(stmt.query_map([favicon_id], |row| {
            Ok(FaviconAsset {
                id: row.get(0)?,
                favicon_id: row.get(1)?,
                r#type: AssetType::from_str(&row.get::<_, String>(2)?).unwrap(),
                size: row.get(3)?,
                format: row.get(4)?,
                storage_key: row.get(5)?,
                mime_type: row.get(6)?,
                created_at: DateTime::parse_from_rfc3339(&row.get::<_, String>(7)?)
                    .unwrap().with_timezone(&Utc),
            })
        }))?
        .collect::<Result<Vec<_>, _>>())?;

        Ok(assets)
    }

    pub fn insert_asset(&self, asset: &FaviconAsset) -> Result<(), HandlerError> {
        db_err!(self.conn.execute(
            "INSERT INTO favicon_assets (id, favicon_id, type, size, format, storage_key, mime_type, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            params![
                asset.id,
                asset.favicon_id,
                asset.r#type.as_str(),
                asset.size,
                asset.format,
                asset.storage_key,
                asset.mime_type,
                asset.created_at.to_rfc3339(),
            ]
        ))?;
        Ok(())
    }

    pub fn delete_assets_by_favicon_id(&self, favicon_id: &str) -> Result<(), HandlerError> {
        db_err!(self.conn.execute("DELETE FROM favicon_assets WHERE favicon_id = ?", [favicon_id]))?;
        Ok(())
    }

    pub fn list_published_favicons(
        &self,
        page: i64,
        page_size: i64,
        sort_by: &str,
        sort_dir: &str,
    ) -> Result<(Vec<DirectoryItem>, i64), HandlerError> {
        // Get total count
        let total: i64 = db_err!(self.conn.query_row(
            "SELECT COUNT(*) FROM favicons WHERE is_published = 1",
            [],
            |row| row.get(0)
        ))?;

        // Map sort_by to column name
        let column = match sort_by {
            "date" => "created_at",
            "url" => "slug",
            "domain" => "target_domain",
            _ => "target_domain",
        };

        let order = if sort_dir == "desc" { "DESC" } else { "ASC" };
        let offset = (page - 1) * page_size;

        let query = format!(
            "SELECT id, slug, title, target_domain, published_url, created_at
             FROM favicons WHERE is_published = 1
             ORDER BY {} {} LIMIT ? OFFSET ?",
            column, order
        );

        let mut stmt = db_err!(self.conn.prepare(&query))?;
        let items = db_err!(db_err!(stmt.query_map(params![page_size, offset], |row| {
            Ok(DirectoryItem {
                id: row.get(0)?,
                slug: row.get(1)?,
                title: row.get(2)?,
                target_domain: row.get(3)?,
                published_url: row.get(4)?,
                created_at: row.get(5)?,
            })
        }))?
        .collect::<Result<Vec<_>, _>>())?;

        Ok((items, total))
    }
}

