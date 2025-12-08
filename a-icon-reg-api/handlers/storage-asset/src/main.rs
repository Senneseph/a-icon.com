use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    storage::StorageService,
    error::{ApiError, ApiResult},
};

#[tokio::main]
async fn main() {
    handler_loop!(handle);
}

async fn handle(req: Request) -> Response {
    match handle_asset(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_asset(req: Request) -> ApiResult<Response> {
    // Extract path from wildcard parameter
    let path = req.path_params.get("path")
        .ok_or_else(|| ApiError::BadRequest("Missing path parameter".to_string()))?;

    // Initialize storage service
    let storage = StorageService::new().await?;

    // Get asset file
    let data = storage.get_object(path).await?;

    // Determine MIME type from file extension
    let mime_type = if let Some(ext) = path.split('.').last() {
        StorageService::mime_type_from_extension(ext)
    } else {
        StorageService::detect_mime_type(&data)
    };

    // Build response with binary data
    let mut response = Response::ok_binary(data);
    response.headers.insert("Content-Type".to_string(), mime_type);
    response.headers.insert("Cache-Control".to_string(), "public, max-age=31536000".to_string());

    Ok(response)
}

