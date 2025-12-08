# Deployment Guide

## Prerequisites

1. **Rust Edge Gateway** running at `https://rust-edge-gateway.iffuso.com`
2. **Environment Variables** configured in the gateway:
   ```bash
   DB_PATH=/data/a-icon.db
   S3_ENDPOINT=https://nyc3.digitaloceanspaces.com
   S3_REGION=nyc3
   S3_BUCKET=a-icon
   S3_ACCESS_KEY=<your-key>
   S3_SECRET_KEY=<your-secret>
   ADMIN_PASSWORD_FILE=/data/.admin-password
   ```
3. **Existing Data**:
   - SQLite database at `/data/a-icon.db`
   - MinIO/S3 bucket with existing favicons
   - Admin password file at `/data/.admin-password`

## Build All Handlers

```bash
cd a-icon-reg-api
chmod +x scripts/build-all.sh
./scripts/build-all.sh
```

This will compile all 11 handlers:
- `health`
- `favicons-upload`
- `favicons-canvas`
- `favicons-get`
- `directory`
- `admin-login`
- `admin-logout`
- `admin-verify`
- `admin-delete`
- `storage-source`
- `storage-asset`

Binaries will be located at:
```
handlers/{handler-name}/target/release/{handler-name}
```

## Route Configuration

Access the Rust Edge Gateway admin UI at `https://rust-edge-gateway.iffuso.com/admin/` and configure these routes:

| Route | Method | Handler Binary | Path Params |
|-------|--------|----------------|-------------|
| `/api/health` | GET | `health` | - |
| `/api/favicons/upload` | POST | `favicons-upload` | - |
| `/api/favicons/canvas` | POST | `favicons-canvas` | - |
| `/api/favicons/:slug` | GET | `favicons-get` | `slug` |
| `/api/directory` | GET | `directory` | - |
| `/api/admin/login` | POST | `admin-login` | - |
| `/api/admin/logout` | POST | `admin-logout` | - |
| `/api/admin/verify` | POST | `admin-verify` | - |
| `/api/admin/favicons` | DELETE | `admin-delete` | - |
| `/api/storage/sources/:faviconId/original` | GET | `storage-source` | `faviconId` |
| `/api/storage/*path` | GET | `storage-asset` | `path` (wildcard) |

## Deployment Steps

### 1. Build Handlers

```bash
cd a-icon-reg-api
./scripts/build-all.sh
```

### 2. Upload Binaries

For each handler, upload the binary to the gateway:

**Option A: Via Admin UI**
1. Navigate to `https://rust-edge-gateway.iffuso.com/admin/`
2. Click "Add Handler"
3. Upload binary file
4. Configure route (method, path, path params)
5. Save

**Option B: Via API** (if available)
```bash
# Example for health handler
curl -X POST https://rust-edge-gateway.iffuso.com/admin/handlers \
  -H "Authorization: Bearer <admin-token>" \
  -F "binary=@handlers/health/target/release/health" \
  -F "route=/api/health" \
  -F "method=GET"
```

### 3. Test Each Endpoint

```bash
# Health check
curl https://a-icon.com/api/health

# Directory listing
curl https://a-icon.com/api/directory

# Get favicon (replace with actual slug)
curl https://a-icon.com/api/favicons/abc123

# Admin login
curl -X POST https://a-icon.com/api/admin/login \
  -H "Content-Type: application/json" \
  -d '{"password":"your-password"}'

# Upload favicon
curl -X POST https://a-icon.com/api/favicons/upload \
  -F "file=@test-image.png" \
  -F "title=Test Favicon" \
  -F "targetDomain=example.com"
```

### 4. Update Frontend (if needed)

The API is 100% compatible with the existing NestJS API, so no frontend changes should be needed. However, verify:

1. All endpoints return the same response format
2. Error messages are consistent
3. Authentication works correctly

### 5. Monitor and Verify

1. Check gateway logs for errors
2. Monitor response times
3. Verify database writes
4. Check storage uploads

### 6. Clean Up Old API

Once verified:

```bash
# SSH into droplet
ssh root@167.71.191.234

# Stop old NestJS container
docker-compose -f /root/a-icon/docker-compose.yml down a-icon-api

# Remove old image
docker rmi a-icon_api

# Update docker-compose.yml to remove a-icon-api service
```

## Troubleshooting

### Handler Won't Start

- Check environment variables are set in gateway
- Verify database file exists and is readable
- Check MinIO credentials are correct
- Review gateway logs for error messages

### Database Errors

- Ensure `/data/a-icon.db` exists
- Check file permissions
- Verify schema is up to date

### Storage Errors

- Verify S3 credentials
- Check bucket name and region
- Test MinIO connectivity

### Authentication Errors

- Verify admin password file exists at `/data/.admin-password`
- Check file permissions
- Ensure password doesn't have trailing newlines

## Rollback Plan

If issues arise:

1. **Keep old API running** during deployment
2. **Use Nginx routing** to switch between old and new:
   ```nginx
   # Route to new Rust handlers
   location /api/ {
       proxy_pass http://rust-edge-gateway:8080;
   }
   
   # Rollback: Route to old NestJS API
   # location /api/ {
   #     proxy_pass http://a-icon-api:3000;
   # }
   ```
3. **Quick rollback**: Just update Nginx config and reload
4. **Fix issues** in Rust handlers
5. **Retry deployment** when ready

## Performance Monitoring

After deployment, monitor:

- **Response times**: Should be 5-10x faster
- **Memory usage**: Should be 5-10x lower
- **Error rates**: Should be same or lower
- **Throughput**: Should be 10x higher

## Success Criteria

✅ All 11 endpoints responding correctly
✅ Frontend works without changes
✅ Database writes successful
✅ Storage uploads/downloads working
✅ Authentication functional
✅ No errors in logs
✅ Performance improved

