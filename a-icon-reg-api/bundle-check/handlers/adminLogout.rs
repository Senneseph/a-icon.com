use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use a_icon_shared::{
    admin::AdminService,
    HandlerError,
};
use serde::Serialize;

#[derive(Serialize)]
struct LogoutResponse {
    success: bool,
}

fn handle(req: Request) -> Response {
    match handle_logout(&req) {
        Ok(response) => response,
        Err(e) => e.to_response(),
    }
}

fn handle_logout(req: &Request) -> Result<Response, HandlerError> {
    // Extract token from Authorization header using SDK helper
    let token = extract_bearer_token(req)?;

    // Initialize admin service
    let admin = AdminService::new()?;

    // Logout (invalidate token)
    admin.logout(&token);

    // Build response
    let response = LogoutResponse { success: true };

    Ok(Response::ok(json!(response)))
}

fn extract_bearer_token(req: &Request) -> Result<String, HandlerError> {
    let auth_header = req.require_header("Authorization")?;

    if !auth_header.starts_with("Bearer ") {
        return Err(HandlerError::Unauthorized("Invalid Authorization header format".to_string()));
    }

    Ok(auth_header[7..].to_string())
}

handler_loop!(handle);

