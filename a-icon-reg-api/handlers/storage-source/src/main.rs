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
    match handle_source(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_source(req: Request) -> ApiResult<Response> {
    // Extract faviconId from path parameter
    let favicon_id = req.path_params.get("faviconId")
        .ok_or_else(|| ApiError::BadRequest("Missing faviconId parameter".to_string()))?;

    // Initialize storage service
    let storage = StorageService::new().await?;

    // Get source image
    let source_key = format!("sources/{}/original", favicon_id);
    let data = storage.get_object(&source_key).await?;

    // Detect MIME type from magic bytes
    let mime_type = StorageService::detect_mime_type(&data);

    // Build response with binary data
    let mut response = Response::ok_binary(data);
    response.headers.insert("Content-Type".to_string(), mime_type);
    response.headers.insert("Cache-Control".to_string(), "public, max-age=31536000".to_string());

    Ok(response)
}

