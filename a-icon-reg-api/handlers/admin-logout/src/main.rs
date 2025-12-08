use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    admin::AdminService,
    error::{ApiError, ApiResult},
};
use serde::Serialize;

#[derive(Serialize)]
struct LogoutResponse {
    success: bool,
}

#[tokio::main]
async fn main() {
    handler_loop!(handle);
}

async fn handle(req: Request) -> Response {
    match handle_logout(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_logout(req: Request) -> ApiResult<Response> {
    // Extract token from Authorization header
    let token = extract_bearer_token(&req)?;

    // Initialize admin service
    let admin = AdminService::new()?;

    // Logout (invalidate token)
    admin.logout(&token);

    // Build response
    let response = LogoutResponse { success: true };

    Ok(Response::ok(serde_json::to_value(response).unwrap()))
}

fn extract_bearer_token(req: &Request) -> ApiResult<String> {
    let auth_header = req.headers.get("authorization")
        .ok_or_else(|| ApiError::Unauthorized("Missing Authorization header".to_string()))?;

    if !auth_header.starts_with("Bearer ") {
        return Err(ApiError::Unauthorized("Invalid Authorization header format".to_string()));
    }

    Ok(auth_header[7..].to_string())
}

