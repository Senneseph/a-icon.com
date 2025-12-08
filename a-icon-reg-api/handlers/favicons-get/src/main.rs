use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    database::Database,
    models::FaviconDetailResponse,
    error::{ApiError, ApiResult},
};
use std::env;

#[tokio::main]
async fn main() {
    handler_loop!(handle);
}

async fn handle(req: Request) -> Response {
    match handle_get(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_get(req: Request) -> ApiResult<Response> {
    // Extract slug from path parameter
    let slug = req.path_params.get("slug")
        .ok_or_else(|| ApiError::BadRequest("Missing slug parameter".to_string()))?;

    // Initialize database
    let db_path = env::var("DB_PATH").unwrap_or_else(|_| "/data/a-icon.db".to_string());
    let db = Database::new(&db_path)?;

    // Get favicon by slug
    let favicon = db.get_favicon_by_slug(slug)?
        .ok_or_else(|| ApiError::NotFound(format!("Favicon not found: {}", slug)))?;

    // Get assets
    let assets = db.get_assets_by_favicon_id(&favicon.id)?;

    // Build response
    let response = FaviconDetailResponse::from_favicon_and_assets(favicon, assets);

    Ok(Response::ok(serde_json::to_value(response).unwrap()))
}

