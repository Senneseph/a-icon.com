use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    storage::StorageService,
    HandlerError,
};

fn handle(req: Request) -> Response {
    match handle_asset(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_asset(req: &Request) -> Result<Response, HandlerError> {
    // Extract path from wildcard parameter using SDK helper
    let path = req.path_param("path")
        .ok_or_else(|| HandlerError::BadRequest("Missing path parameter".to_string()))?;

    // Create tokio runtime for async storage operations
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| HandlerError::InternalError(e.to_string()))?;

    // Initialize storage service
    let storage = rt.block_on(async {
        StorageService::new().await
            .map_err(|e| HandlerError::StorageError(format!("Failed to initialize storage: {}", e)))
    })?;

    // Get asset file
    let data = rt.block_on(async {
        storage.get_object(path).await
    })?;

    // Determine MIME type from file extension
    let mime_type = if let Some(ext) = path.split('.').last() {
        StorageService::mime_type_from_extension(ext)
    } else {
        StorageService::detect_mime_type(&data)
    };

    // Build response with binary data using SDK helper
    Ok(Response::binary(200, data, &mime_type)
        .with_cache(31536000))
}

handler_loop!(handle);

