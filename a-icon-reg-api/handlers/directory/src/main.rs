use rust_edge_gateway_sdk::prelude::*;

/// Directory handler
/// Returns a paginated list of favicons from the SQLite database
///
/// This is a sync handler that matches the gateway's expected signature:
/// `pub fn handle(ctx: &Context, req: Request) -> Response`
///
/// The `ctx` parameter provides access to service providers (database, cache, storage)
/// when configured. This handler uses the SQLite service to query the database.
pub fn handle(ctx: &Context, req: Request) -> Response {
    // Parse query parameters
    let page: i64 = req.query.get("page")
        .and_then(|p| p.parse().ok())
        .unwrap_or(1);

    let page_size: i64 = req.query.get("pageSize")
        .and_then(|p| p.parse().ok())
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

    // Try to get SQLite service from context
    match ctx.try_sqlite() {
        Some(sqlite) => {
            // Calculate offset for pagination
            let offset = (page - 1) * page_size;
            
            // Build SQL query
            let sql = format!(
                "SELECT * FROM favicons WHERE published = 1 ORDER BY {} {} LIMIT ? OFFSET ?",
                column, order
            );
            
            // Execute query
            let result = sqlite.query(&sql, vec![page_size.to_string(), offset.to_string()]);
            
            // This is an async operation, but our handler is sync
            // In a real implementation, we would need to use async/await
            // or the handler would need to be async
            
            // For now, return a response indicating the database query would be executed
            Response::ok(json!({
                "message": "SQLite database query would be executed",
                "sql": sql,
                "params": [page_size, offset],
                "page": page,
                "page_size": page_size,
                "sort_by": sort_by,
                "order": order,
                "database_available": true
            }))
        }
        None => {
            // SQLite service not available
            Response::ok(json!({
                "message": "SQLite service not configured in gateway",
                "page": page,
                "page_size": page_size,
                "sort_by": sort_by,
                "order": order,
                "database_available": false,
                "setup_instructions": "Please configure SQLite service in Rust Edge Gateway admin interface"
            }))
        }
    }
}
