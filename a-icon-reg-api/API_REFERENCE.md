# A-Icon API Reference

Quick reference for all API endpoints. See `openapi.yaml` for complete specification.

## Base URL

- Production: `https://a-icon.com/api`
- Local: `http://localhost:3000/api`

## Endpoints

### Health Check

```http
GET /health
```

**Response:**
```json
{
  "status": "ok",
  "timestamp": "2025-12-08T12:00:00.000Z"
}
```

---

### Upload Favicon

```http
POST /favicons/upload
Content-Type: multipart/form-data
```

**Request Body:**
- `file` (required): Image file (max 0.5 MB)
- `title` (optional): Favicon title (max 256 chars)
- `targetDomain` (optional): Domain name (max 256 chars, must have TLD)
- `metadata` (optional): Secret metadata (max 256 chars)

**Response:** `FaviconDetail` object (see below)

**Validation:**
- File size: max 0.5 MB (512 KB)
- File type: image/* only
- Domain: must contain dot with content before/after
- Metadata: max 256 characters

---

### Create from Canvas

```http
POST /favicons/canvas
Content-Type: application/json
```

**Request Body:**
```json
{
  "dataUrl": "data:image/png;base64,...",
  "title": "Optional title",
  "targetDomain": "example.com",
  "metadata": "Optional secret metadata"
}
```

**Response:** `FaviconDetail` object

---

### Get Favicon Details

```http
GET /favicons/:slug
```

**Response:**
```json
{
  "id": "uuid",
  "slug": "url-friendly-slug",
  "title": "Favicon Title",
  "targetDomain": "example.com",
  "publishedUrl": "https://a-icon.com/f/slug",
  "sourceUrl": "/api/storage/sources/uuid/original",
  "sourceType": "UPLOAD",
  "isPublished": true,
  "createdAt": "2025-12-08T12:00:00.000Z",
  "generatedAt": "2025-12-08T12:00:01.000Z",
  "generationStatus": "SUCCESS",
  "generationError": null,
  "metadata": "Secret metadata",
  "hasSteganography": true,
  "assets": [
    {
      "id": "asset-uuid",
      "type": "PNG",
      "size": "192x192",
      "format": ".png",
      "mimeType": "image/png",
      "url": "/api/storage/uuid/PNG-192x192.png"
    }
  ]
}
```

---

### List Directory

```http
GET /directory?page=1&pageSize=100&sortBy=domain&order=asc
```

**Query Parameters:**
- `page` (default: 1): Page number
- `pageSize` (default: 100, max: 500): Items per page
- `sortBy` (default: domain): `createdAt`, `slug`, or `domain`
- `order` (default: asc): `asc` or `desc`

**Response:**
```json
{
  "items": [
    {
      "id": "uuid",
      "slug": "slug",
      "title": "Title",
      "targetDomain": "example.com",
      "publishedUrl": "https://a-icon.com/f/slug",
      "createdAt": "2025-12-08T12:00:00.000Z"
    }
  ],
  "total": 150,
  "page": 1,
  "pageSize": 100,
  "totalPages": 2
}
```

---

### Admin Login

```http
POST /admin/login
Content-Type: application/json
```

**Request Body:**
```json
{
  "password": "admin-password"
}
```

**Response:**
```json
{
  "token": "session-token",
  "expiresAt": "2025-12-08T13:00:00.000Z"
}
```

---

### Admin Logout

```http
POST /admin/logout
Authorization: Bearer <token>
```

**Response:**
```json
{
  "success": true
}
```

---

### Admin Verify Token

```http
POST /admin/verify
Authorization: Bearer <token>
```

**Response:**
```json
{
  "valid": true
}
```

---

### Admin Delete Favicons

```http
DELETE /admin/favicons
Authorization: Bearer <token>
Content-Type: application/json
```

**Request Body:**
```json
{
  "ids": ["uuid1", "uuid2", "uuid3"]
}
```

**Response:**
```json
{
  "results": [
    {
      "id": "uuid1",
      "success": true
    },
    {
      "id": "uuid2",
      "success": false,
      "error": "Not found"
    }
  ]
}
```

---

### Get Source Image

```http
GET /storage/sources/:faviconId/original
```

**Response:** Binary image data (PNG, JPEG, GIF, or SVG)

**Headers:**
- `Content-Type`: Detected from image magic bytes
- `Cache-Control`: `public, max-age=31536000` (1 year)

---

### Get Asset File

```http
GET /storage/:path
```

**Response:** Binary file data

**Headers:**
- `Content-Type`: Determined from file extension
- `Cache-Control`: `public, max-age=31536000` (1 year)

---

## Error Responses

All errors follow this format:

```json
{
  "statusCode": 400,
  "message": "Detailed error message",
  "error": "Bad Request"
}
```

**Status Codes:**
- `400` - Bad Request (validation errors)
- `401` - Unauthorized (invalid/missing auth)
- `404` - Not Found (resource doesn't exist)
- `500` - Internal Server Error

---

## Data Models

### SourceType
- `UPLOAD` - Uploaded image file
- `CANVAS` - Canvas-created image

### GenerationStatus
- `PENDING` - Generation in progress
- `SUCCESS` - Generation completed
- `FAILED` - Generation failed

### AssetType
- `ICO` - .ico file
- `PNG` - .png file
- `SVG` - .svg file

---

## Validation Rules

### Domain Name
- Max 256 characters
- Must contain at least one dot (.)
- Must have content before and after dot
- Format: `[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)+`
- Examples:
  - ✅ `example.com`
  - ✅ `sub.example.com`
  - ✅ `my-site.example.com`
  - ❌ `example` (no dot)
  - ❌ `example.` (nothing after dot)
  - ❌ `.example.com` (nothing before dot)
  - ❌ `example..com` (empty part)

### File Size
- Max 0.5 MB (524,288 bytes)

### Metadata
- Max 256 characters (for JPEG EXIF compatibility)

### Image Types
- PNG (magic bytes: `89 50 4E 47`)
- JPEG (magic bytes: `FF D8 FF`)
- GIF (magic bytes: `47 49 46`)
- SVG (starts with `<svg` or `<?xml`)

