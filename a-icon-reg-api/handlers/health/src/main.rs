use rust_edge_gateway_sdk::{prelude::*, handler_loop};
use chrono::Utc;

fn handle(_req: Request) -> Response {
    Response::ok(json!({
        "status": "ok",
        "timestamp": Utc::now().to_rfc3339(),
    }))
}

handler_loop!(handle);

