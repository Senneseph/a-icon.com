# A-Icon Rust Edge Gateway Implementation Plan

## Overview

This document outlines the plan to migrate the a-icon API from NestJS to Rust Edge Gateway.

## Goals

1. ✅ Create OpenAPI specification for existing API
2. 🔄 Implement Rust Edge Gateway handlers
3. 🔄 Maintain API compatibility
4. 🔄 Deploy to production
5. 🔄 Clean up old NestJS Docker image

## Project Structure

```
a-icon-reg-api/
├── openapi.yaml              ✅ Complete - API specification
├── README.md                 ✅ Complete - Project documentation
├── IMPLEMENTATION_PLAN.md    ✅ This file
├── shared/                   🔄 In Progress - Shared Rust library
│   ├── Cargo.toml           ✅ Complete
│   └── src/
│       ├── lib.rs           ✅ Complete
│       ├── error.rs         ✅ Complete - Error handling
│       ├── models.rs        ✅ Complete - Data models
│       ├── validation.rs    ✅ Complete - Validation logic
│       ├── database.rs      ⏳ TODO - SQLite database layer
│       └── storage.rs       ⏳ TODO - MinIO storage layer
└── handlers/                 🔄 In Progress - Request handlers
    ├── health/              ✅ Complete - Health check
    │   ├── Cargo.toml
    │   └── src/main.rs
    ├── favicons/            ⏳ TODO - Favicon operations
    │   ├── upload/          ⏳ TODO - POST /favicons/upload
    │   ├── canvas/          ⏳ TODO - POST /favicons/canvas
    │   └── get/             ⏳ TODO - GET /favicons/:slug
    ├── directory/           ⏳ TODO - GET /directory
    ├── admin/               ⏳ TODO - Admin operations
    │   ├── login/           ⏳ TODO - POST /admin/login
    │   ├── logout/          ⏳ TODO - POST /admin/logout
    │   ├── verify/          ⏳ TODO - POST /admin/verify
    │   └── delete/          ⏳ TODO - DELETE /admin/favicons
    └── storage/             ⏳ TODO - File serving
        ├── source/          ⏳ TODO - GET /storage/sources/:id/original
        └── asset/           ⏳ TODO - GET /storage/:path
```

## Implementation Steps

### Phase 1: Foundation ✅ COMPLETE

- [x] Create OpenAPI specification
- [x] Set up project structure
- [x] Create shared library skeleton
- [x] Implement error handling
- [x] Implement data models
- [x] Implement validation logic
- [x] Create health check handler (example)

### Phase 2: Core Services ⏳ NEXT

- [ ] Implement database service (SQLite)
  - [ ] Connection management
  - [ ] Favicon CRUD operations
  - [ ] Asset CRUD operations
  - [ ] Directory queries
  - [ ] Duplicate detection (hash + size)
- [ ] Implement storage service (MinIO)
  - [ ] S3 client configuration
  - [ ] Upload operations
  - [ ] Download operations
  - [ ] Delete operations
- [ ] Implement admin service
  - [ ] Password verification
  - [ ] Session token management
  - [ ] Token validation

### Phase 3: Favicon Handlers ⏳ TODO

- [ ] POST /favicons/upload
  - [ ] Multipart form parsing
  - [ ] File validation
  - [ ] Domain validation
  - [ ] Metadata validation
  - [ ] Duplicate detection
  - [ ] Favicon generation
  - [ ] Storage upload
  - [ ] Database insertion
- [ ] POST /favicons/canvas
  - [ ] Base64 decoding
  - [ ] Image validation
  - [ ] Favicon generation
- [ ] GET /favicons/:slug
  - [ ] Database query
  - [ ] Asset retrieval
  - [ ] Response formatting

### Phase 4: Directory & Admin Handlers ⏳ TODO

- [ ] GET /directory
  - [ ] Pagination
  - [ ] Sorting
  - [ ] Filtering
- [ ] POST /admin/login
  - [ ] Password verification
  - [ ] Token generation
- [ ] POST /admin/logout
  - [ ] Token invalidation
- [ ] POST /admin/verify
  - [ ] Token validation
- [ ] DELETE /admin/favicons
  - [ ] Authentication check
  - [ ] Batch deletion
  - [ ] Storage cleanup
  - [ ] Database cleanup

### Phase 5: Storage Handlers ⏳ TODO

- [ ] GET /storage/sources/:id/original
  - [ ] MinIO retrieval
  - [ ] MIME type detection
  - [ ] Cache headers
- [ ] GET /storage/:path
  - [ ] MinIO retrieval
  - [ ] MIME type mapping
  - [ ] Cache headers

### Phase 6: Testing & Deployment ⏳ TODO

- [ ] Unit tests for shared library
- [ ] Integration tests for handlers
- [ ] Build all handlers
- [ ] Deploy to Rust Edge Gateway
- [ ] Configure routes in gateway
- [ ] Test all endpoints
- [ ] Update frontend to use new API
- [ ] Monitor for issues

### Phase 7: Cleanup ⏳ TODO

- [ ] Stop old NestJS container
- [ ] Remove a-icon_api Docker image from droplet
- [ ] Update documentation
- [ ] Archive old a-icon-api directory

## API Compatibility

The new implementation maintains 100% API compatibility:

| Endpoint | Method | NestJS | Rust Gateway | Status |
|----------|--------|--------|--------------|--------|
| /health | GET | ✅ | ✅ | Complete |
| /favicons/upload | POST | ✅ | ⏳ | TODO |
| /favicons/canvas | POST | ✅ | ⏳ | TODO |
| /favicons/:slug | GET | ✅ | ⏳ | TODO |
| /directory | GET | ✅ | ⏳ | TODO |
| /admin/login | POST | ✅ | ⏳ | TODO |
| /admin/logout | POST | ✅ | ⏳ | TODO |
| /admin/verify | POST | ✅ | ⏳ | TODO |
| /admin/favicons | DELETE | ✅ | ⏳ | TODO |
| /storage/sources/:id/original | GET | ✅ | ⏳ | TODO |
| /storage/:path | GET | ✅ | ⏳ | TODO |

## Data Compatibility

- **Database**: Same SQLite schema, no migration needed
- **Storage**: Same MinIO structure, no migration needed
- **Admin Password**: Same password file (`.admin-password`)

## Configuration

Environment variables needed:

```bash
# Database
DB_PATH=/data/a-icon.db

# MinIO/S3
S3_ENDPOINT=https://nyc3.digitaloceanspaces.com
S3_REGION=nyc3
S3_BUCKET=a-icon
S3_ACCESS_KEY=<from DO Spaces>
S3_SECRET_KEY=<from DO Spaces>

# Admin
ADMIN_PASSWORD_FILE=/data/.admin-password

# Gateway
GATEWAY_URL=https://rust-edge-gateway.iffuso.com
```

## Next Steps

1. **Implement database service** - Core data access layer
2. **Implement storage service** - MinIO/S3 integration
3. **Create favicon upload handler** - Most complex endpoint
4. **Test with existing data** - Ensure compatibility
5. **Deploy incrementally** - One endpoint at a time

## Notes

- The Rust Edge Gateway SDK provides the `Request` and `Response` types
- Handlers communicate with the gateway via IPC (stdin/stdout)
- Each handler is a standalone binary
- Shared code is in the `a-icon-shared` library
- All handlers will be compiled and registered in the gateway admin UI

