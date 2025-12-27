#!/bin/bash
# Setup SQLite service and test endpoint
# This script configures the SQLite service actor and creates a test endpoint

set -e

API_URL="${API_URL:-http://localhost:8081}"

echo "=============================================="
echo "  SQLite Service Setup"
echo "  Admin API: $API_URL"
echo "=============================================="

# Get domain ID
echo ""
echo "1. Getting domain ID..."
DOMAIN_ID=$(curl -s "$API_URL/api/domains" | jq -r '.data[] | select(.name=="a-icon.com") | .id')
echo "   Domain ID: $DOMAIN_ID"

if [ -z "$DOMAIN_ID" ]; then
    echo "ERROR: Domain 'a-icon.com' not found. Run setup-gateway.sh first."
    exit 1
fi

# 2. Create SQLite service
echo ""
echo "2. Creating SQLite service..."
SERVICE_RESPONSE=$(curl -s -X POST "$API_URL/api/services" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "a-icon-db",
    "service_type": "sqlite",
    "config": {
      "path": "/app/data/a-icon.db",
      "create_if_missing": true
    }
  }')
echo "   Response: $SERVICE_RESPONSE"

SERVICE_ID=$(echo "$SERVICE_RESPONSE" | jq -r '.data.id // empty')
if [ -z "$SERVICE_ID" ]; then
    echo "   Service may already exist, fetching..."
    SERVICE_ID=$(curl -s "$API_URL/api/services" | jq -r '.data[] | select(.name=="a-icon-db") | .id')
fi
echo "   Service ID: $SERVICE_ID"

if [ -z "$SERVICE_ID" ]; then
    echo "ERROR: Could not create SQLite service"
    exit 1
fi

# 3. Activate the service
echo ""
echo "3. Activating SQLite service..."
ACTIVATE_RESPONSE=$(curl -s -X POST "$API_URL/api/services/$SERVICE_ID/activate")
echo "   Response: $ACTIVATE_RESPONSE"

# 4. Create SQLite test endpoint
echo ""
echo "4. Creating SQLite test endpoint..."

# V2 handler using the Context to access SQLite service
# The handler! macro creates a dynamic library that receives Context
SQLITE_TEST_CODE='use rust_edge_gateway_sdk::prelude::*;

handler!(async fn sqlite_test(ctx: &Context, req: Request) -> Response {
    // Try to get the SQLite service
    let db = match ctx.try_sqlite() {
        Some(db) => db,
        None => return Response::internal_error("SQLite service not configured"),
    };

    // Create test table if not exists
    let create_sql = "CREATE TABLE IF NOT EXISTS test_table (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        message TEXT NOT NULL,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    )";

    if let Err(e) = db.execute(create_sql, vec![]).await {
        return Response::internal_error(&format!("Failed to create table: {}", e));
    }

    // Insert a test record with current timestamp
    let message = format!("Test at request {}", ctx.request_id);
    let insert_sql = "INSERT INTO test_table (message) VALUES (?)";

    let rows_affected = match db.execute(insert_sql, vec![message.clone()]).await {
        Ok(n) => n,
        Err(e) => return Response::internal_error(&format!("Failed to insert: {}", e)),
    };

    // Read back recent records
    let query_sql = "SELECT id, message, created_at FROM test_table ORDER BY id DESC LIMIT 5";
    let rows = match db.query(query_sql, vec![]).await {
        Ok(rows) => rows,
        Err(e) => return Response::internal_error(&format!("Failed to query: {}", e)),
    };

    Response::ok(json!({
        "status": "success",
        "message": "SQLite service is working!",
        "inserted_message": message,
        "rows_affected": rows_affected,
        "recent_records": rows,
        "path": req.path
    }))
});'

# Create the endpoint with service binding
ENDPOINT_RESPONSE=$(curl -s -X POST "$API_URL/api/endpoints" \
  -H "Content-Type: application/json" \
  -d "{
    \"domain_id\": \"$DOMAIN_ID\",
    \"name\": \"SQLite Test\",
    \"path\": \"/api/sqlite-test\",
    \"method\": \"GET\",
    \"handler_code\": $(echo "$SQLITE_TEST_CODE" | jq -Rs .),
    \"service_bindings\": [\"$SERVICE_ID\"]
  }")
echo "   Response: $ENDPOINT_RESPONSE"

ENDPOINT_ID=$(echo "$ENDPOINT_RESPONSE" | jq -r '.data.id // empty')
echo "   Endpoint ID: $ENDPOINT_ID"

# 5. Compile the endpoint
echo ""
echo "5. Compiling SQLite test endpoint..."
COMPILE_RESPONSE=$(curl -s -X POST "$API_URL/api/endpoints/$ENDPOINT_ID/compile")
echo "   Response: $COMPILE_RESPONSE"

# 6. Start the endpoint
echo ""
echo "6. Starting SQLite test endpoint..."
START_RESPONSE=$(curl -s -X POST "$API_URL/api/endpoints/$ENDPOINT_ID/start")
echo "   Response: $START_RESPONSE"

# 7. Test the endpoint
echo ""
echo "7. Testing SQLite test endpoint..."
sleep 2
TEST_RESPONSE=$(curl -s "http://localhost:8080/api/sqlite-test" -H "Host: a-icon.com")
echo "   Response: $TEST_RESPONSE"

echo ""
echo "=============================================="
echo "  SQLite Service Setup Complete!"
echo "=============================================="

