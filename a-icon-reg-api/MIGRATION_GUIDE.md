# Migration Guide: NestJS to Rust Edge Gateway

## Overview

This guide shows how the A-Icon API is being migrated from NestJS to Rust Edge Gateway, maintaining 100% API compatibility while gaining performance and isolation benefits.

## Architecture Comparison

### Before (NestJS)

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Client    │────▶│  NestJS API      │────▶│  SQLite + MinIO │
│  (Browser)  │     │  (Node.js)       │     │  (Data Storage) │
└─────────────┘     └──────────────────┘     └─────────────────┘
                            │
                            ▼
                    ┌───────────────┐
                    │  Docker       │
                    │  Container    │
                    └───────────────┘
```

**Characteristics:**
- Single Node.js process
- All endpoints in one codebase
- Restart required for updates
- Memory-based isolation only

### After (Rust Edge Gateway)

```
┌─────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Client    │────▶│  Edge Gateway    │────▶│  Rust Handlers  │
│  (Browser)  │     │  (Routes)        │     │  (Compiled)     │
└─────────────┘     └──────────────────┘     └─────────────────┘
                            │                         │
                            ▼                         ▼
                    ┌───────────────────────────────────┐
                    │      SQLite + MinIO               │
                    │      (Data Storage)               │
                    └───────────────────────────────────┘
```

**Characteristics:**
- Multiple worker processes
- Each endpoint is a separate binary
- Hot reload without restart
- Process-level isolation

## Code Comparison

### Health Check Endpoint

#### NestJS (`a-icon-api/src/health/health.controller.ts`)

```typescript
import { Controller, Get } from '@nestjs/common';

@Controller('health')
export class HealthController {
  @Get()
  getHealth() {
    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
    };
  }
}
```

#### Rust Edge Gateway (`a-icon-reg-api/handlers/health/src/main.rs`)

```rust
use rust_edge_gateway_sdk::prelude::*;
use chrono::Utc;

fn handle(_req: Request) -> Response {
    Response::ok(json!({
        "status": "ok",
        "timestamp": Utc::now().to_rfc3339(),
    }))
}

handler_loop!(handle);
```

**Key Differences:**
- Rust: Standalone binary vs TypeScript module
- Rust: Explicit request/response vs decorators
- Rust: Compiled native code vs interpreted JavaScript
- Rust: Process isolation vs shared memory

### Validation Logic

#### NestJS (`a-icon-api/src/favicon/favicon.controller.ts`)

```typescript
private validateDomain(domain: string): void {
  if (domain.length > 256) {
    throw new BadRequestException(
      'Domain name must not exceed 256 characters',
    );
  }

  if (!domain.includes('.')) {
    throw new BadRequestException(
      'Domain name must contain at least one dot (.)',
    );
  }

  const domainRegex =
    /^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$/;
  if (!domainRegex.test(domain)) {
    throw new BadRequestException('Invalid domain name format...');
  }
}
```

#### Rust Edge Gateway (`a-icon-reg-api/shared/src/validation.rs`)

```rust
pub fn validate_domain(domain: &str) -> ApiResult<()> {
    if domain.len() > 256 {
        return Err(ApiError::ValidationError(
            "Domain name must not exceed 256 characters".to_string(),
        ));
    }

    if !domain.contains('.') {
        return Err(ApiError::ValidationError(
            "Domain name must contain at least one dot (.)".to_string(),
        ));
    }

    let domain_regex = Regex::new(
        r"^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+$"
    ).unwrap();

    if !domain_regex.is_match(domain) {
        return Err(ApiError::ValidationError(
            "Invalid domain name format...".to_string(),
        ));
    }

    Ok(())
}
```

**Key Differences:**
- Rust: Shared library vs controller method
- Rust: Result type vs exceptions
- Rust: Compile-time type safety vs runtime checks
- Rust: Reusable across handlers vs tied to controller

## Data Models

### NestJS (TypeScript Interfaces)

```typescript
export interface Favicon {
  id: string;
  slug: string;
  title: string | null;
  target_domain: string | null;
  published_url: string;
  source_type: 'UPLOAD' | 'CANVAS';
  is_published: number; // SQLite uses 0/1
  created_at: string;
  generation_status: 'PENDING' | 'SUCCESS' | 'FAILED';
  metadata: string | null;
  has_steganography: number;
}
```

### Rust (Structs with Serde)

```rust
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Favicon {
    pub id: String,
    pub slug: String,
    pub title: Option<String>,
    pub target_domain: Option<String>,
    pub published_url: String,
    pub source_type: SourceType,
    pub is_published: bool,
    pub created_at: DateTime<Utc>,
    pub generation_status: GenerationStatus,
    pub metadata: Option<String>,
    pub has_steganography: bool,
}
```

**Key Differences:**
- Rust: Strong typing with enums vs string literals
- Rust: `Option<T>` vs `null`
- Rust: `bool` vs `number` (0/1)
- Rust: `DateTime<Utc>` vs `string`
- Rust: Compile-time guarantees vs runtime checks

## Database Access

### NestJS (better-sqlite3)

```typescript
getFaviconBySlug(slug: string): Favicon | undefined {
  const stmt = this.db.prepare(
    'SELECT * FROM favicons WHERE slug = ?'
  );
  return stmt.get(slug) as Favicon | undefined;
}
```

### Rust (rusqlite)

```rust
pub fn get_favicon_by_slug(&self, slug: &str) -> ApiResult<Option<Favicon>> {
    let mut stmt = self.conn.prepare(
        "SELECT * FROM favicons WHERE slug = ?"
    )?;
    
    let favicon = stmt.query_row([slug], |row| {
        Ok(Favicon {
            id: row.get(0)?,
            slug: row.get(1)?,
            // ... map all fields
        })
    }).optional()?;
    
    Ok(favicon)
}
```

**Key Differences:**
- Rust: Explicit error handling with `?` operator
- Rust: Type-safe row mapping
- Rust: Compile-time SQL validation (with sqlx)
- Rust: Result type vs undefined

## Deployment

### NestJS

```bash
# Build
npm run build

# Create Docker image
docker build -t a-icon_api .

# Run container
docker run -p 3000:3000 a-icon_api
```

**Characteristics:**
- Single Docker container
- All endpoints in one process
- Restart required for updates
- ~100MB+ image size

### Rust Edge Gateway

```bash
# Build handlers
./scripts/build-all.sh

# Upload to gateway (via admin UI)
# - Upload binary for each endpoint
# - Configure route
# - Test

# Or use API
curl -X POST https://gateway/admin/handlers \
  -F "binary=@target/release/health" \
  -F "route=/api/health"
```

**Characteristics:**
- Multiple binaries
- Each endpoint separate
- Hot reload per endpoint
- ~5-10MB per binary

## Performance Comparison

### Expected Improvements

| Metric | NestJS | Rust Gateway | Improvement |
|--------|--------|--------------|-------------|
| Response Time | ~10-50ms | ~1-5ms | 5-10x faster |
| Memory Usage | ~100MB | ~10-20MB | 5-10x less |
| Throughput | ~1000 req/s | ~10000 req/s | 10x more |
| Cold Start | ~1-2s | ~10-50ms | 20-40x faster |

*Note: Actual numbers depend on workload and hardware*

### Why Faster?

1. **Compiled Code**: Native machine code vs interpreted JavaScript
2. **No GC**: Manual memory management vs garbage collection
3. **Zero-cost Abstractions**: Rust's design philosophy
4. **Process Isolation**: No shared memory contention

## Migration Checklist

### Pre-Migration

- [x] Document existing API (OpenAPI spec)
- [x] Set up Rust project structure
- [x] Create shared library
- [x] Implement validation logic
- [x] Create example handler

### Migration

- [ ] Implement database service
- [ ] Implement storage service
- [ ] Create all handlers
- [ ] Build and test locally
- [ ] Deploy to staging
- [ ] Test with frontend
- [ ] Deploy to production

### Post-Migration

- [ ] Monitor performance
- [ ] Verify all endpoints work
- [ ] Update documentation
- [ ] Stop old NestJS container
- [ ] Remove old Docker image
- [ ] Archive old codebase

## Rollback Plan

If issues arise:

1. **Keep old API running** during migration
2. **Use DNS/routing** to switch between old and new
3. **Monitor logs** for errors
4. **Quick rollback**: Point traffic back to old API
5. **Fix issues** in new implementation
6. **Retry migration** when ready

## Benefits of Migration

### Performance
- ✅ 5-10x faster response times
- ✅ 10x higher throughput
- ✅ Lower memory usage
- ✅ Faster cold starts

### Reliability
- ✅ Process isolation (crash doesn't affect other endpoints)
- ✅ Type safety (compile-time error detection)
- ✅ Memory safety (no null pointer errors)
- ✅ Concurrent safety (no data races)

### Operations
- ✅ Hot reload (update without restart)
- ✅ Smaller binaries (easier deployment)
- ✅ Better resource utilization
- ✅ Easier debugging (isolated processes)

### Development
- ✅ Shared library (code reuse)
- ✅ Strong typing (better IDE support)
- ✅ Compile-time checks (catch errors early)
- ✅ Better testing (unit tests in Rust)

## Challenges

### Learning Curve
- Rust syntax and ownership model
- Different error handling patterns
- New tooling (Cargo vs npm)

### Solutions
- Use existing NestJS code as reference
- Follow Rust Edge Gateway examples
- Leverage shared library for common code

### Migration Effort
- Need to rewrite all handlers
- Test each endpoint thoroughly
- Coordinate with frontend team

### Solutions
- Incremental migration (one endpoint at a time)
- Maintain API compatibility
- Automated testing

## Conclusion

The migration from NestJS to Rust Edge Gateway provides significant performance and reliability improvements while maintaining 100% API compatibility. The modular handler architecture makes it easy to update individual endpoints without affecting the entire system.

