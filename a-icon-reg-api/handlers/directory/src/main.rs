use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    database::Database,
    models::DirectoryResponse,
    error::ApiError,
};
use std::env;

fn handle(req: Request) -> Response {
    match handle_directory(&req) {
        Ok(response) => response,
        Err(e) => Response::json(e.status_code(), json!(e.to_json())),
    }
}

fn handle_directory(req: &Request) -> Result<Response, ApiError> {
    // Parse query parameters
    let page = req.query.get("page")
        .and_then(|p| p.parse::<i64>().ok())
        .unwrap_or(1);

    let page_size = req.query.get("pageSize")
        .and_then(|p| p.parse::<i64>().ok())
        .unwrap_or(100)
        .min(500); // Max 500 items per page

    let sort_by = req.query.get("sortBy")
        .map(|s| s.as_str())
        .unwrap_or("domain");

    let order = req.query.get("order")
        .map(|s| s.as_str())
        .unwrap_or("asc");

    // Map frontend sortBy values to backend column names
    let column = match sort_by {
        "createdAt" => "date",
        "slug" => "url",
        "domain" => "domain",
        _ => "domain",
    };

    // Initialize database
    let db_path = env::var("DB_PATH").unwrap_or_else(|_| "/data/a-icon.db".to_string());
    let db = Database::new(&db_path)?;

    // Get paginated results
    let (items, total) = db.list_published_favicons(page, page_size, column, order)?;

    // Calculate total pages
    let total_pages = (total as f64 / page_size as f64).ceil() as i64;

    // Build response
    let response = DirectoryResponse {
        items,
        total,
        page,
        page_size,
        total_pages,
    };

    Ok(Response::ok(json!(response)))
}

handler_loop!(handle);

