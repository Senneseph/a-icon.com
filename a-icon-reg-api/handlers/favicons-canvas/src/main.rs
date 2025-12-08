use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    database::Database,
    storage::StorageService,
    validation::{validate_domain, validate_metadata, validate_file_size, validate_image_type},
    models::{Favicon, SourceType, GenerationStatus, FaviconDetailResponse},
    error::{ApiError, ApiResult},
    utils::generate_short_id,
};
use chrono::Utc;
use uuid::Uuid;
use serde::Deserialize;
use std::env;

#[derive(Deserialize)]
struct CanvasRequest {
    #[serde(rename = "dataUrl")]
    data_url: String,
    title: Option<String>,
    #[serde(rename = "targetDomain")]
    target_domain: Option<String>,
    metadata: Option<String>,
}

#[tokio::main]
async fn main() {
    handler_loop!(handle);
}

async fn handle(req: Request) -> Response {
    match handle_canvas(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_canvas(req: Request) -> ApiResult<Response> {
    // Parse JSON body
    let canvas_req: CanvasRequest = serde_json::from_slice(&req.body)
        .map_err(|e| ApiError::BadRequest(format!("Invalid JSON: {}", e)))?;

    // Parse data URL
    let (mime_type, image_data) = parse_data_url(&canvas_req.data_url)?;

    // Validate file size
    validate_file_size(image_data.len())?;

    // Validate image type
    validate_image_type(&image_data)?;

    // Validate domain if provided
    if let Some(ref domain) = canvas_req.target_domain {
        validate_domain(domain)?;
    }

    // Validate metadata if provided
    if let Some(ref meta) = canvas_req.metadata {
        validate_metadata(meta)?;
    }

    // Calculate hash and size for duplicate detection
    let source_hash = format!("{:x}", md5::compute(&image_data));
    let source_size = image_data.len() as i64;

    // Initialize services
    let db_path = env::var("DB_PATH").unwrap_or_else(|_| "/data/a-icon.db".to_string());
    let db = Database::new(&db_path)?;
    let storage = StorageService::new().await?;

    // Check for duplicate
    if let Some(existing) = db.find_duplicate(&source_hash, source_size)? {
        // Return existing favicon details
        let assets = db.get_assets_by_favicon_id(&existing.id)?;
        let response = FaviconDetailResponse::from_favicon_and_assets(existing, assets);
        return Ok(Response::ok(serde_json::to_value(response).unwrap()));
    }

    // Generate IDs
    let id = Uuid::new_v4().to_string();
    let slug = generate_short_id(10);
    let now = Utc::now();

    // Store source image
    let source_key = format!("sources/{}/original", id);
    storage.upload_object(&source_key, image_data, &mime_type).await?;

    // Create favicon record
    let has_metadata = canvas_req.metadata.as_ref().map(|m| !m.trim().is_empty()).unwrap_or(false);
    let favicon = Favicon {
        id: id.clone(),
        slug: slug.clone(),
        title: canvas_req.title,
        target_domain: canvas_req.target_domain,
        published_url: format!("/f/{}", slug),
        canonical_svg_key: None,
        source_type: SourceType::Canvas,
        source_original_mime: Some(mime_type),
        source_hash: Some(source_hash),
        source_size: Some(source_size),
        is_published: true,
        created_at: now,
        updated_at: now,
        generated_at: None,
        generation_status: GenerationStatus::Pending,
        generation_error: None,
        metadata: if has_metadata { canvas_req.metadata } else { None },
        has_steganography: false,
    };

    db.insert_favicon(&favicon)?;

    // TODO: Generate favicon assets asynchronously
    
    let assets = db.get_assets_by_favicon_id(&id)?;
    let response = FaviconDetailResponse::from_favicon_and_assets(favicon, assets);

    Ok(Response::ok(serde_json::to_value(response).unwrap()))
}

fn parse_data_url(data_url: &str) -> ApiResult<(String, Vec<u8>)> {
    // Format: data:image/png;base64,iVBORw0KGgo...
    if !data_url.starts_with("data:") {
        return Err(ApiError::BadRequest("Invalid data URL format".to_string()));
    }

    let parts: Vec<&str> = data_url[5..].splitn(2, ',').collect();
    if parts.len() != 2 {
        return Err(ApiError::BadRequest("Invalid data URL format".to_string()));
    }

    let header = parts[0];
    let data = parts[1];

    // Extract MIME type
    let mime_parts: Vec<&str> = header.split(';').collect();
    let mime_type = mime_parts[0].to_string();

    // Check if base64 encoded
    if !header.contains("base64") {
        return Err(ApiError::BadRequest("Only base64-encoded data URLs are supported".to_string()));
    }

    // Decode base64
    let decoded = base64::decode(data)
        .map_err(|e| ApiError::BadRequest(format!("Invalid base64 data: {}", e)))?;

    Ok((mime_type, decoded))
}

