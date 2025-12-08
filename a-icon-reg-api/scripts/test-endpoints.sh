#!/bin/bash
# Test all A-Icon API endpoints

set -e

# Configuration
BASE_URL="${BASE_URL:-https://a-icon.com/api}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-}"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=== Testing A-Icon API Endpoints ==="
echo "Base URL: $BASE_URL"
echo ""

# Test counter
PASSED=0
FAILED=0

test_endpoint() {
    local name="$1"
    local method="$2"
    local path="$3"
    local data="$4"
    local expected_status="$5"
    
    echo -n "Testing $name... "
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" "$BASE_URL$path" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    if [ "$status" = "$expected_status" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $status)"
        PASSED=$((PASSED + 1))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} (Expected HTTP $expected_status, got $status)"
        echo "Response: $body"
        FAILED=$((FAILED + 1))
        return 1
    fi
}

# 1. Health Check
echo -e "${BLUE}[1/11] Health Check${NC}"
test_endpoint "GET /health" "GET" "/health" "" "200"
echo ""

# 2. Directory Listing
echo -e "${BLUE}[2/11] Directory Listing${NC}"
test_endpoint "GET /directory" "GET" "/directory" "" "200"
test_endpoint "GET /directory?page=1&pageSize=10" "GET" "/directory?page=1&pageSize=10" "" "200"
test_endpoint "GET /directory?sortBy=domain&order=asc" "GET" "/directory?sortBy=domain&order=asc" "" "200"
echo ""

# 3. Get Favicon (will fail if no favicons exist)
echo -e "${BLUE}[3/11] Get Favicon${NC}"
echo "Skipping - requires existing favicon slug"
echo ""

# 4. Admin Login
echo -e "${BLUE}[4/11] Admin Login${NC}"
if [ -z "$ADMIN_PASSWORD" ]; then
    echo "Skipping - ADMIN_PASSWORD not set"
else
    if test_endpoint "POST /admin/login" "POST" "/admin/login" "{\"password\":\"$ADMIN_PASSWORD\"}" "200"; then
        # Extract token from response
        TOKEN=$(echo "$body" | grep -o '"token":"[^"]*"' | cut -d'"' -f4)
        echo "Token: $TOKEN"
    fi
fi
echo ""

# 5. Admin Verify
echo -e "${BLUE}[5/11] Admin Verify${NC}"
if [ -z "$TOKEN" ]; then
    echo "Skipping - no token available"
else
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/admin/verify" \
        -H "Authorization: Bearer $TOKEN")
    status=$(echo "$response" | tail -n1)
    if [ "$status" = "200" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $status)"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC} (Expected HTTP 200, got $status)"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# 6. Admin Logout
echo -e "${BLUE}[6/11] Admin Logout${NC}"
if [ -z "$TOKEN" ]; then
    echo "Skipping - no token available"
else
    response=$(curl -s -w "\n%{http_code}" -X POST "$BASE_URL/admin/logout" \
        -H "Authorization: Bearer $TOKEN")
    status=$(echo "$response" | tail -n1)
    if [ "$status" = "200" ]; then
        echo -e "${GREEN}✓ PASS${NC} (HTTP $status)"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC} (Expected HTTP 200, got $status)"
        FAILED=$((FAILED + 1))
    fi
fi
echo ""

# 7. Upload Favicon
echo -e "${BLUE}[7/11] Upload Favicon${NC}"
echo "Skipping - requires test image file"
echo ""

# 8. Canvas Favicon
echo -e "${BLUE}[8/11] Canvas Favicon${NC}"
echo "Skipping - requires base64 data URL"
echo ""

# 9. Admin Delete
echo -e "${BLUE}[9/11] Admin Delete${NC}"
echo "Skipping - requires valid favicon IDs and token"
echo ""

# 10. Storage Source
echo -e "${BLUE}[10/11] Storage Source${NC}"
echo "Skipping - requires existing favicon ID"
echo ""

# 11. Storage Asset
echo -e "${BLUE}[11/11] Storage Asset${NC}"
echo "Skipping - requires existing asset path"
echo ""

# Summary
echo "=== Test Summary ==="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi

