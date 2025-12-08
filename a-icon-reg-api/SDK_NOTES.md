# Rust Edge Gateway SDK Notes

## Key Learnings

### 1. Handler Signature
Handlers must be **synchronous** functions, not async:
```rust
fn handle(req: Request) -> Response {
    // ...
}
```

NOT:
```rust
async fn handle(req: Request) -> Response {
    // ...
}
```

### 2. Request API
- `req.method` - HTTP method (String)
- `req.path` - Request path (String)
- `req.query` - Query parameters (HashMap<String, String>)
- `req.headers` - HTTP headers (HashMap<String, String>)
- `req.body` - Request body (Vec<u8>)

### 3. Response API
- `Response::ok(json!({...}))` - 200 OK with JSON body
- `Response::json(status, json!({...}))` - Custom status with JSON body
- `Response::text(status, "text")` - Custom status with text body
- `Response::new(status)` - Custom status with empty body

NO `Response::error()` method exists!

### 4. JSON Macro
Use the `json!()` macro from serde_json (via prelude):
```rust
Response::ok(json!({
    "key": "value",
    "number": 42
}))
```

### 5. Handler Loop Macro
Must be called at the end of main.rs:
```rust
handler_loop!(handle);
```

### 6. Dependencies
All handlers must use git dependency for SDK:
```toml
rust-edge-gateway-sdk = { git = "https://github.com/Senneseph/rust-edge-gateway.git" }
```

### 7. AWS SDK Versions
Must use older versions compatible with Rust 1.86.0:
```bash
cargo update aws-sdk-s3 --precise 1.50.0
cargo update aws-config --precise 1.5.0
cargo update aws-sdk-sso --precise 1.40.0
cargo update aws-sdk-ssooidc --precise 1.40.0
cargo update aws-sdk-sts --precise 1.40.0
```

### 8. Async Operations in Sync Handlers
For handlers that need async operations (database, storage), we need to use a runtime:
```rust
fn handle(req: Request) -> Response {
    // Create a runtime for async operations
    let rt = tokio::runtime::Runtime::new().unwrap();
    rt.block_on(async {
        // async code here
    })
}
```

## Fixes Needed for Remaining Handlers

All handlers need these changes:

1. **Remove `#[tokio::main]` and `async fn main()`**
2. **Make `handle` function synchronous**
3. **Use `tokio::runtime::Runtime` for async operations**
4. **Change `req.query_params` to `req.query`**
5. **Change `Response::error()` to `Response::json()`**
6. **Use `json!()` macro for responses**
7. **Update Cargo.toml to use git SDK dependency** (already done)
8. **Downgrade AWS SDK versions** (needs to be done per handler)

## Example Pattern

```rust
use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{...};

fn handle(req: Request) -> Response {
    match handle_impl(&req) {
        Ok(response) => response,
        Err(e) => Response::json(e.status_code(), json!(e.to_json())),
    }
}

fn handle_impl(req: &Request) -> Result<Response, ApiError> {
    // For async operations:
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| ApiError::InternalError(e.to_string()))?;
    
    rt.block_on(async {
        // Your async code here
        let result = some_async_function().await?;
        Ok(Response::ok(json!(result)))
    })
}

handler_loop!(handle);
```

## Status

✅ **health** - Compiled successfully
✅ **directory** - Compiled successfully  
⏳ **favicons-upload** - Needs fixes
⏳ **favicons-canvas** - Needs fixes
⏳ **favicons-get** - Needs fixes
⏳ **admin-login** - Needs fixes
⏳ **admin-logout** - Needs fixes
⏳ **admin-verify** - Needs fixes
⏳ **admin-delete** - Needs fixes
⏳ **storage-source** - Needs fixes
⏳ **storage-asset** - Needs fixes

