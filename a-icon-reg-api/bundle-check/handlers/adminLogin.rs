use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    admin::AdminService,
    HandlerError,
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

fn handle(req: Request) -> Response {
    match handle_login(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_login(req: &Request) -> Result<Response, HandlerError> {
    // Parse JSON body using new SDK helper
    let login_req: LoginRequest = req.json()?;

    // Initialize admin service
    let admin = AdminService::new()?;

    // Verify password and create session
    let (token, expires_at) = admin.verify_password(&login_req.password)?;

    // Build response
    let response = LoginResponse {
        token,
        expires_at: expires_at.to_rfc3339(),
    };

    Ok(Response::ok(json!(response)))
}

handler_loop!(handle);

