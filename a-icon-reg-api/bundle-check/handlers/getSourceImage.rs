use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    storage::StorageService,
    HandlerError,
};

fn handle(req: Request) -> Response {
    match handle_source(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_source(req: &Request) -> Result<Response, HandlerError> {
    // Extract faviconId from path parameter using SDK helper
    let favicon_id = req.path_param("faviconId")
        .ok_or_else(|| HandlerError::BadRequest("Missing faviconId parameter".to_string()))?;

    // Create tokio runtime for async storage operations
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| HandlerError::InternalError(e.to_string()))?;

    // Initialize storage service
    let storage = rt.block_on(async {
        StorageService::new().await
            .map_err(|e| HandlerError::StorageError(format!("Failed to initialize storage: {}", e)))
    })?;

    // Get source image
    let source_key = format!("sources/{}/original", favicon_id);
    let data = rt.block_on(async {
        storage.get_object(&source_key).await
    })?;

    // Detect MIME type from magic bytes
    let mime_type = StorageService::detect_mime_type(&data);

    // Build response with binary data using SDK helper
    Ok(Response::binary(200, data, &mime_type)
        .with_cache(31536000))
}

handler_loop!(handle);

