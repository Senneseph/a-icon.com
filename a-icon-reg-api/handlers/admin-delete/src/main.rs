use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    admin::AdminService,
    database::Database,
    storage::StorageService,
    HandlerError,
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

fn handle(req: Request) -> Response {
    match handle_delete(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_delete(req: &Request) -> Result<Response, HandlerError> {
    // Extract token from Authorization header
    let token = extract_bearer_token(req)?;

    // Initialize admin service and verify token
    let admin = AdminService::new()?;
    if !admin.verify_token(&token) {
        return Err(HandlerError::Unauthorized("Invalid or expired token".to_string()));
    }

    // Parse JSON body using SDK helper
    let delete_req: DeleteRequest = req.json()?;

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

    // Delete each favicon
    let mut results = Vec::new();
    for id in delete_req.ids {
        let result = rt.block_on(delete_favicon(&db, &storage, &id));
        results.push(result);
    }

    // Build response
    let response = DeleteResponse { results };

    Ok(Response::ok(json!(response)))
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

fn extract_bearer_token(req: &Request) -> Result<String, HandlerError> {
    let auth_header = req.require_header("Authorization")?;

    if !auth_header.starts_with("Bearer ") {
        return Err(HandlerError::Unauthorized("Invalid Authorization header format".to_string()));
    }

    Ok(auth_header[7..].to_string())
}

handler_loop!(handle);

