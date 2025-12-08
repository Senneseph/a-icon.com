# Getting Started with A-Icon Rust Edge Gateway

## What We've Created

This directory contains the foundation for migrating the A-Icon API from NestJS to Rust Edge Gateway. Here's what's been set up:

### ✅ Completed

1. **OpenAPI Specification** (`openapi.yaml`)
   - Complete API documentation
   - All 11 endpoints documented
   - Request/response schemas
   - Authentication requirements

2. **Project Structure**
   - Organized handler directories
   - Shared library for common code
   - Clear separation of concerns

3. **Shared Library** (`shared/`)
   - Error handling (`error.rs`)
   - Data models (`models.rs`)
   - Validation logic (`validation.rs`)
   - Library structure (`lib.rs`)

4. **Example Handler** (`handlers/health/`)
   - Working health check endpoint
   - Demonstrates handler pattern
   - Ready to compile and deploy

5. **Documentation**
   - `README.md` - Project overview
   - `IMPLEMENTATION_PLAN.md` - Detailed roadmap
   - `GETTING_STARTED.md` - This file

### ⏳ Next Steps

To complete the implementation, you need to:

1. **Implement Database Service** (`shared/src/database.rs`)
   - SQLite connection management
   - Favicon CRUD operations
   - Asset CRUD operations
   - Duplicate detection queries

2. **Implement Storage Service** (`shared/src/storage.rs`)
   - MinIO/S3 client setup
   - Upload/download/delete operations
   - MIME type detection

3. **Create Favicon Handlers** (`handlers/favicons/`)
   - Upload handler (multipart form)
   - Canvas handler (base64 decode)
   - Get handler (retrieve details)

4. **Create Admin Handlers** (`handlers/admin/`)
   - Login (password verification)
   - Logout (token invalidation)
   - Verify (token validation)
   - Delete (batch deletion)

5. **Create Storage Handlers** (`handlers/storage/`)
   - Source image serving
   - Asset file serving

6. **Create Directory Handler** (`handlers/directory/`)
   - Paginated listing
   - Sorting and filtering

## How to Build a Handler

Each handler follows this pattern:

```rust
use rust_edge_gateway_sdk::prelude::*;

fn handle(req: Request) -> Response {
    // 1. Parse request
    // 2. Validate input
    // 3. Process (database, storage, etc.)
    // 4. Return response
    
    Response::ok(json!({
        "message": "Success"
    }))
}

handler_loop!(handle);
```

### Example: Health Check Handler

See `handlers/health/src/main.rs` for a complete working example.

### Building a Handler

```bash
cd handlers/health
cargo build --release
```

The compiled binary will be at `target/release/health`.

### Registering with Gateway

1. Access the Rust Edge Gateway admin UI
2. Create a new endpoint
3. Upload the compiled binary
4. Configure the route (e.g., `/api/health`)
5. Test the endpoint

## Development Workflow

1. **Write handler code** in `handlers/{name}/src/main.rs`
2. **Use shared library** for common functionality
3. **Build the handler** with `cargo build --release`
4. **Test locally** (optional: create test harness)
5. **Deploy to gateway** via admin UI
6. **Test in production** with real requests

## Shared Library Usage

Import the shared library in your handler's `Cargo.toml`:

```toml
[dependencies]
a-icon-shared = { path = "../../shared" }
```

Then use it in your handler:

```rust
use a_icon_shared::{
    models::{Favicon, FaviconAsset},
    validation::{validate_domain, validate_metadata},
    error::{ApiError, ApiResult},
};
```

## Testing Strategy

1. **Unit tests** in shared library
   - Validation logic
   - Data model conversions
   - Error handling

2. **Integration tests** for handlers
   - Mock database/storage
   - Test request/response flow
   - Verify error cases

3. **End-to-end tests**
   - Deploy to staging gateway
   - Test with real frontend
   - Verify data persistence

## Deployment Process

### Option 1: Manual Deployment

1. Build each handler
2. Upload to gateway admin UI
3. Configure routes
4. Test endpoints

### Option 2: Automated Deployment (TODO)

Create a deployment script that:
- Builds all handlers
- Uploads to gateway via API
- Configures routes
- Runs smoke tests

## Migration Strategy

### Incremental Migration

1. **Deploy new handlers alongside old API**
   - Old: `https://a-icon.com/api/*`
   - New: `https://a-icon.com/api/v2/*` (temporary)

2. **Test thoroughly**
   - Verify all endpoints work
   - Check data compatibility
   - Monitor performance

3. **Switch over**
   - Update frontend to use new endpoints
   - Monitor for issues
   - Keep old API running as backup

4. **Clean up**
   - Stop old NestJS container
   - Remove old Docker image
   - Update documentation

### Big Bang Migration (Alternative)

1. **Build and test all handlers**
2. **Deploy all at once**
3. **Switch DNS/routing**
4. **Monitor closely**

## Environment Setup

### Required Services

- **Rust Edge Gateway** - Running at `https://rust-edge-gateway.iffuso.com`
- **SQLite Database** - At `/data/a-icon.db` (existing)
- **MinIO/S3 Storage** - DigitalOcean Spaces (existing)

### Environment Variables

Configure in the gateway:

```bash
DB_PATH=/data/a-icon.db
S3_ENDPOINT=https://nyc3.digitaloceanspaces.com
S3_REGION=nyc3
S3_BUCKET=a-icon
S3_ACCESS_KEY=<your-key>
S3_SECRET_KEY=<your-secret>
ADMIN_PASSWORD_FILE=/data/.admin-password
```

## Troubleshooting

### Handler won't compile

- Check Rust version: `rustc --version` (need 1.70+)
- Update dependencies: `cargo update`
- Check for syntax errors in shared library

### Handler crashes on startup

- Check environment variables are set
- Verify database file exists and is readable
- Check MinIO credentials are correct

### Gateway can't find handler

- Verify binary is uploaded to gateway
- Check route configuration in admin UI
- Ensure binary has execute permissions

## Next Actions

1. **Review the OpenAPI spec** (`openapi.yaml`) to understand all endpoints
2. **Study the health handler** (`handlers/health/`) as a template
3. **Implement database service** as the foundation
4. **Start with simple handlers** (health, directory) before complex ones (upload)
5. **Test incrementally** - don't wait until everything is done

## Resources

- [Rust Edge Gateway Docs](https://docs.rust-edge-gateway.iffuso.com)
- [OpenAPI Specification](./openapi.yaml)
- [Implementation Plan](./IMPLEMENTATION_PLAN.md)
- [Project README](./README.md)

