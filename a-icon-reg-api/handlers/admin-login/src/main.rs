use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    admin::AdminService,
    error::{ApiError, ApiResult},
};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct LoginRequest {
    password: String,
}

#[derive(Serialize)]
struct LoginResponse {
    token: String,
    #[serde(rename = "expiresAt")]
    expires_at: String,
}

#[tokio::main]
async fn main() {
    handler_loop!(handle);
}

async fn handle(req: Request) -> Response {
    match handle_login(req).await {
        Ok(response) => response,
        Err(e) => Response::error(e.status_code(), e.to_json()),
    }
}

async fn handle_login(req: Request) -> ApiResult<Response> {
    // Parse JSON body
    let login_req: LoginRequest = serde_json::from_slice(&req.body)
        .map_err(|e| ApiError::BadRequest(format!("Invalid JSON: {}", e)))?;

    // Initialize admin service
    let admin = AdminService::new()?;

    // Verify password and create session
    let (token, expires_at) = admin.verify_password(&login_req.password)?;

    // Build response
    let response = LoginResponse {
        token,
        expires_at: expires_at.to_rfc3339(),
    };

    Ok(Response::ok(serde_json::to_value(response).unwrap()))
}

