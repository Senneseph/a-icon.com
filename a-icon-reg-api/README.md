# A-Icon Rust Edge Gateway API

This directory contains the Rust Edge Gateway implementation of the A-Icon API, replacing the NestJS-based `a-icon-api`.

## Overview

The A-Icon API provides favicon generation and management with metadata and steganography support. This implementation uses Rust Edge Gateway for high-performance, isolated request handling.

## Architecture

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Client    │────▶│  Edge Gateway    │────▶│  Rust Handlers  │
│  (Browser)  │     │  (Routes)        │     │  (Compiled)     │
└─────────────┘     └──────────────────┘     └─────────────────┘
                            │
                            ▼
                    ┌───────────────────┐
                    │   SQLite + MinIO  │
                    │   (Data Storage)  │
                    └───────────────────┘
```

## Directory Structure

```
a-icon-reg-api/
├── openapi.yaml           # OpenAPI 3.0 specification
├── README.md              # This file
├── handlers/              # Rust handler implementations
│   ├── health/            # Health check endpoint
│   ├── favicons/          # Favicon CRUD operations
│   ├── directory/         # Public directory listing
│   ├── admin/             # Admin authentication & deletion
│   └── storage/           # File serving
├── shared/                # Shared Rust code
│   ├── models/            # Data models
│   ├── database/          # SQLite database layer
│   ├── storage/           # MinIO/S3 storage layer
│   └── utils/             # Utilities (validation, etc.)
└── scripts/               # Deployment and build scripts
```

## API Endpoints

### Health
- `GET /api/health` - Health check

### Favicons
- `POST /api/favicons/upload` - Upload image to generate favicon
- `POST /api/favicons/canvas` - Create favicon from canvas data
- `GET /api/favicons/:slug` - Get favicon details

### Directory
- `GET /api/directory` - List published favicons (paginated)

### Admin (Authentication Required)
- `POST /api/admin/login` - Admin login
- `POST /api/admin/logout` - Admin logout
- `POST /api/admin/verify` - Verify session token
- `DELETE /api/admin/favicons` - Delete favicons

### Storage
- `GET /api/storage/sources/:faviconId/original` - Get source image
- `GET /api/storage/:path` - Get stored asset file

## Features

- ✅ **Favicon Generation**: Upload or canvas-based favicon creation
- ✅ **Metadata Support**: Store metadata in EXIF and steganographically
- ✅ **Duplicate Detection**: MD5 hash and file size comparison
- ✅ **Domain Validation**: 256 character limit with TLD syntax validation
- ✅ **Admin Authentication**: Session-based admin access
- ✅ **Public Directory**: Paginated listing of published favicons
- ✅ **Asset Storage**: MinIO/S3-compatible object storage

## Data Models

### Favicon
- `id`: Unique identifier
- `slug`: URL-friendly slug
- `title`: Optional title
- `target_domain`: Target domain name (validated)
- `published_url`: Published URL
- `source_type`: UPLOAD or CANVAS
- `source_hash`: MD5 hash for duplicate detection
- `source_size`: File size for duplicate detection
- `metadata`: Secret metadata (max 256 chars)
- `has_steganography`: Whether steganography was applied
- `generation_status`: PENDING, SUCCESS, or FAILED

### FaviconAsset
- `id`: Asset identifier
- `favicon_id`: Parent favicon ID
- `type`: ICO, PNG, or SVG
- `size`: Asset dimensions (e.g., '16x16', '192x192')
- `format`: File extension
- `storage_key`: MinIO object key
- `mime_type`: MIME type

## Storage

- **Database**: SQLite (better-sqlite3 compatible schema)
- **Object Storage**: MinIO (S3-compatible)
  - Source images: `sources/{faviconId}/original`
  - Generated assets: `{faviconId}/{type}-{size}.{format}`

## Validation Rules

- **File Size**: Max 0.5 MB (512 KB)
- **Domain**: Max 256 chars, must contain dot with content before/after
- **Metadata**: Max 256 chars (JPEG EXIF compatibility)
- **File Types**: Images only (PNG, JPEG, GIF, SVG)

## Migration from NestJS

This implementation maintains API compatibility with the existing NestJS `a-icon-api`:
- Same endpoints and request/response formats
- Same database schema (SQLite)
- Same storage structure (MinIO)
- Same validation rules

## Deployment

See `scripts/deploy.sh` for deployment instructions.

## Development

Each handler is a standalone Rust binary that:
1. Receives requests via IPC from the gateway
2. Processes the request using shared libraries
3. Returns responses to the gateway

Handlers are compiled and registered with the Rust Edge Gateway admin UI.

