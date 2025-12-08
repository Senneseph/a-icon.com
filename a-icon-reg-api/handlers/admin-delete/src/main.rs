use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    admin::AdminService,
    database::Database,
    storage::StorageService,
    error::{ApiError, ApiResult},
};
use serde::{Deserialize, Serialize};
use std::env;

#[derive(Deserialize)]
struct DeleteRequest {
    ids: Vec<String>,
}

#[derive(Serialize)]
struct DeleteResult {
    id: String,
    success: bool,
    #[serde(skip_serializing_if = "Option::is_none")]
    error: Option<String>,
}

#[derive(Serialize)]
struct DeleteResponse {
    results: Vec<DeleteResult>,
}

#[tokio::main]
async fn main() {
    handler_loop!(handle);
}

async fn handle(req: Request) -> Response {
    match handle_delete(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_delete(req: Request) -> ApiResult<Response> {
    // Extract token from Authorization header
    let token = extract_bearer_token(&req)?;

    // Initialize admin service and verify token
    let admin = AdminService::new()?;
    if !admin.verify_token(&token) {
        return Err(ApiError::Unauthorized("Invalid or expired token".to_string()));
    }

    // Parse JSON body
    let delete_req: DeleteRequest = serde_json::from_slice(&req.body)
        .map_err(|e| ApiError::BadRequest(format!("Invalid JSON: {}", e)))?;

    // Initialize services
    let db_path = env::var("DB_PATH").unwrap_or_else(|_| "/data/a-icon.db".to_string());
    let db = Database::new(&db_path)?;
    let storage = StorageService::new().await?;

    // Delete each favicon
    let mut results = Vec::new();
    for id in delete_req.ids {
        let result = delete_favicon(&db, &storage, &id).await;
        results.push(result);
    }

    // Build response
    let response = DeleteResponse { results };

    Ok(Response::ok(serde_json::to_value(response).unwrap()))
}

async fn delete_favicon(db: &Database, storage: &StorageService, id: &str) -> DeleteResult {
    // Get favicon to retrieve storage keys
    let favicon = match db.get_favicon_by_id(id) {
        Ok(Some(f)) => f,
        Ok(None) => {
            return DeleteResult {
                id: id.to_string(),
                success: false,
                error: Some("Not found".to_string()),
            };
        }
        Err(e) => {
            return DeleteResult {
                id: id.to_string(),
                success: false,
                error: Some(format!("Database error: {}", e)),
            };
        }
    };

    // Get assets
    let assets = match db.get_assets_by_favicon_id(id) {
        Ok(assets) => assets,
        Err(e) => {
            return DeleteResult {
                id: id.to_string(),
                success: false,
                error: Some(format!("Failed to get assets: {}", e)),
            };
        }
    };

    // Delete source image from storage
    let source_key = format!("sources/{}/original", id);
    let _ = storage.delete_object(&source_key).await;

    // Delete all assets from storage
    for asset in assets {
        let _ = storage.delete_object(&asset.storage_key).await;
    }

    // Delete assets from database
    if let Err(e) = db.delete_assets_by_favicon_id(id) {
        return DeleteResult {
            id: id.to_string(),
            success: false,
            error: Some(format!("Failed to delete assets: {}", e)),
        };
    }

    // Delete favicon from database
    if let Err(e) = db.delete_favicon(id) {
        return DeleteResult {
            id: id.to_string(),
            success: false,
            error: Some(format!("Failed to delete favicon: {}", e)),
        };
    }

    DeleteResult {
        id: id.to_string(),
        success: true,
        error: None,
    }
}

fn extract_bearer_token(req: &Request) -> ApiResult<String> {
    let auth_header = req.headers.get("authorization")
        .ok_or_else(|| ApiError::Unauthorized("Missing Authorization header".to_string()))?;

    if !auth_header.starts_with("Bearer ") {
        return Err(ApiError::Unauthorized("Invalid Authorization header format".to_string()));
    }

    Ok(auth_header[7..].to_string())
}

