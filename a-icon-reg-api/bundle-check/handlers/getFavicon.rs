use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    database::Database,
    models::FaviconDetailResponse,
    HandlerError,
};
use std::env;

fn handle(req: Request) -> Response {
    match handle_get(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_get(req: &Request) -> Result<Response, HandlerError> {
    // Extract slug from path parameter
    let slug = req.path_param("slug")
        .ok_or_else(|| HandlerError::BadRequest("Missing slug parameter".to_string()))?;

    // Initialize database
    let db_path = env::var("DB_PATH")
        .map_err(|e| HandlerError::InternalError(format!("DB_PATH not set: {}", e)))?;
    let db = Database::new(&db_path)?;

    // Get favicon by slug
    let favicon = db.get_favicon_by_slug(slug)?
        .ok_or_else(|| HandlerError::NotFoundMessage(format!("Favicon not found: {}", slug)))?;

    // Get assets
    let assets = db.get_assets_by_favicon_id(&favicon.id)?;

    // Build response
    let response = FaviconDetailResponse::from_favicon_and_assets(favicon, assets);

    Ok(Response::ok(json!(response)))
}

handler_loop!(handle);

