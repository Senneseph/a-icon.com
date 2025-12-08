use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    database::Database,
    storage::StorageService,
    validation::{validate_domain, validate_metadata, validate_file_size, validate_image_type},
    models::{Favicon, SourceType, GenerationStatus, FaviconDetailResponse},
    HandlerError,
    utils::{parse_multipart, generate_short_id},
};
use chrono::Utc;
use uuid::Uuid;
use std::env;

fn handle(req: Request) -> Response {
    match handle_upload(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_upload(req: &Request) -> Result<Response, HandlerError> {
    // Parse multipart form data
    let content_type = req.headers.get("content-type")
        .ok_or_else(|| HandlerError::ValidationError("Missing Content-Type header".to_string()))?;

    let body_bytes = req.body.as_ref()
        .ok_or_else(|| HandlerError::ValidationError("Missing request body".to_string()))?
        .as_bytes();

    let boundary = extract_boundary(content_type)?;
    let multipart = parse_multipart(body_bytes, &boundary)?;

    // Extract file
    let file_part = multipart.get_file("file")
        .ok_or_else(|| HandlerError::ValidationError("No file uploaded".to_string()))?;

    // Extract form fields
    let title = multipart.get_field("title");
    let target_domain = multipart.get_field("targetDomain");
    let metadata = multipart.get_field("metadata");

    // Validate file size
    validate_file_size(file_part.content.len())?;

    // Validate file type
    let mime_type = file_part.content_type.clone()
        .ok_or_else(|| HandlerError::ValidationError("Missing file content type".to_string()))?;

    if !mime_type.starts_with("image/") {
        return Err(HandlerError::ValidationError("Only image files are allowed".to_string()));
    }

    validate_image_type(&file_part.content)?;

    // Validate domain if provided
    if let Some(domain) = &target_domain {
        validate_domain(domain)?;
    }

    // Validate metadata if provided
    if let Some(meta) = &metadata {
        validate_metadata(meta)?;
    }

    // Calculate hash and size for duplicate detection
    let source_hash = format!("{:x}", md5::compute(&file_part.content));
    let source_size = file_part.content.len() as i64;

    // Initialize services
    let db_path = env::var("DB_PATH")
        .map_err(|e| HandlerError::InternalError(format!("DB_PATH not set: {}", e)))?;
    let db = Database::new(&db_path)?;

    // Create tokio runtime for async storage operations
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| HandlerError::InternalError(e.to_string()))?;

    let storage = rt.block_on(async {
        StorageService::new().await
            .map_err(|e| HandlerError::StorageError(format!("Failed to initialize storage: {}", e)))
    })?;

    // Check for duplicate
    if let Some(existing) = db.find_duplicate(&source_hash, source_size)? {
        // Return existing favicon details
        let assets = db.get_assets_by_favicon_id(&existing.id)?;
        let response = FaviconDetailResponse::from_favicon_and_assets(existing, assets);
        return Ok(Response::ok(json!(response)));
    }

    // Generate IDs
    let id = Uuid::new_v4().to_string();
    let slug = generate_short_id(10);
    let now = Utc::now();

    // Store source image
    let source_key = format!("sources/{}/original", id);
    rt.block_on(async {
        storage.upload_object(&source_key, file_part.content.clone(), &mime_type).await
    })?;

    // Create favicon record
    let has_metadata = metadata.as_ref().map(|m| !m.trim().is_empty()).unwrap_or(false);
    let favicon = Favicon {
        id: id.clone(),
        slug: slug.clone(),
        title,
        target_domain,
        published_url: format!("/f/{}", slug),
        canonical_svg_key: None,
        source_type: SourceType::Upload,
        source_original_mime: Some(mime_type),
        source_hash: Some(source_hash),
        source_size: Some(source_size),
        is_published: true,
        created_at: now,
        updated_at: now,
        generated_at: None,
        generation_status: GenerationStatus::Pending,
        generation_error: None,
        metadata: if has_metadata { metadata } else { None },
        has_steganography: false,
    };

    db.insert_favicon(&favicon)?;

    // TODO: Generate favicon assets asynchronously
    // For now, just return the favicon with pending status

    let assets = db.get_assets_by_favicon_id(&id)?;
    let response = FaviconDetailResponse::from_favicon_and_assets(favicon, assets);

    Ok(Response::ok(json!(response)))
}

fn extract_boundary(content_type: &str) -> Result<String, HandlerError> {
    let parts: Vec<&str> = content_type.split(';').collect();
    for part in parts {
        let trimmed = part.trim();
        if trimmed.starts_with("boundary=") {
            return Ok(trimmed[9..].trim_matches('"').to_string());
        }
    }
    Err(HandlerError::ValidationError("Missing boundary in Content-Type".to_string()))
}

handler_loop!(handle);

