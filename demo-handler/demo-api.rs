// Simple demo handler for testing Rust Edge Gateway deployment
// This handler responds to GET requests at /api/demo-api

use rust_edge_gateway_sdk::{Request, Response, HandlerError};
use serde_json::json;

fn handle(req: Request) -> Response {
    match handle_demo_api(&req) {
        Ok(response) => response,
        Err(err) => {
            eprintln!("Error in demo handler: {}", err);
            Response::json(
                json!({
                    "error": "Internal server error",
                    "details": err.to_string()
                }),
                500
            )
        }
    }
}

fn handle_demo_api(req: &Request) -> Result<Response, HandlerError> {
    // Only allow GET requests
    if req.method != "GET" {
        return Ok(Response::json(
            json!({
                "error": "Method not allowed",
                "message": "This endpoint only supports GET requests"
            }),
            405
        ));
    }

    // Return a simple demo response
    Ok(Response::json(
        json!({
            "message": "Hello from Rust Edge Gateway Demo API!",
            "timestamp": chrono::Utc::now().to_rfc3339(),
            "path": req.path,
            "method": req.method,
            "headers": req.headers,
            "query": req.query_params
        }),
        200
    ))
}

// Export the handler function
#[no_mangle]
pub extern "C" fn handle_request(req: Request) -> Response {
    handle(req)
}