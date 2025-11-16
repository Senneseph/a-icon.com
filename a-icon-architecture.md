
## a-icon.com – Detailed Architecture & Implementation Plan

Below is a detailed, single-file plan, organized so we can later turn each section into concrete tasks and implementations.

---

## 1. Product Overview & Goals

**Goal:**  
a-icon.com is a web service where users can:

1. Upload an image and convert it into:
   - A favicon (multi-size `.ico` or `.png` set)  
   - Additional **common website icon sizes** exposed via **SVG** (and PNG where required, e.g. Apple touch icons).
2. Create a favicon from scratch using an **MS-Paint-level drawing canvas**.
3. Receive a **unique URL** for each generated favicon (e.g. `/f/{slug}`).
4. Browse a **directory of published favicons**, sortable by:
   - Publish date
   - Published URL (alphabetical)
   - Target domain name (alphabetical)
5. Run fully inside **secured, hardened Docker containers**, ideally deployed on DigitalOcean using Terraform.

Tech preferences (from constraints):

- Frontend: **Angular**, TypeScript
- Backend: **NestJS**, TypeScript
- Architecture: **Functional, idempotent**, dependency-injected; avoid side effects where possible.
- Containerization: **Docker** (+ `docker-compose` locally); hardened runtime.
- IaC: **Terraform**, targeting **DigitalOcean** (Droplet/App Platform + Spaces + Managed DB).

---

## 2. Functional Requirements

### 2.1 User Flows

1. **Image Upload → Favicon**
   - User visits landing page.
   - Chooses “Upload image”.
   - Uploads PNG/JPEG/SVG (max size limit, e.g. 5–10 MB).
   - Optionally specifies:
     - Target domain (e.g. `example.com`)
     - Display name or title
   - Chooses:
     - Which favicon set to generate (default “standard web + iOS”).
   - Backend processes image:
     - Generates base favicon and additional sizes (see 2.2).
     - Stores canonical representation (SVG + derived PNG/ICO) and metadata.
   - System returns:
     - Unique URL for favicon (e.g. `https://a-icon.com/f/my-cool-icon`).
     - Download links for each asset.
     - Snippets of HTML `<link>` tags.

2. **Canvas Editor → Favicon**
   - From landing page, user chooses “Create from scratch”.
   - Opens an Angular-based **canvas editor** (MS-Paint-level).
   - User draws icon (pencil, shapes, fill, text, color, undo/redo, simple zoom, grid).
   - On “Save & Generate”:
     - Frontend sends SVG (or a structured drawing model) to backend.
     - Backend converts to raster formats and builds icon set.
     - Same flow as upload (unique URL, downloads, snippets).

3. **View & Download Existing Favicon**
   - Visiting a favicon URL (`/f/{slug}`) shows:
     - Preview (various sizes).
     - Downloads for each size/format.
     - HTML integration snippets.
     - Published metadata (domain, title, publish date).
   - Some favicons may be “unpublished” (hidden from directory but still accessible via direct URL).

4. **Directory of Favicons**
   - User visits `/directory`.
   - Sees paginated grid/list of favicons with:
     - Thumbnail
     - Title
     - Target domain
     - Published URL
     - Publish date
   - Sort options:
     - Publish date (ascending / descending)
     - Published URL (alphabetical)
     - Domain name (alphabetical)
   - Filter options (optional, future):
     - By domain substring
     - By date range
   - Clicking an entry goes to its favicon detail page.

---

### 2.2 Output Formats & Sizes

We want a canonical representation plus derived assets:

1. **Canonical**
   - Primary: **SVG** (vector or raster-wrapped-in-SVG).
   - Internal resolution baseline (e.g. 512x512 or 1024x1024 logical pixels).

2. **Standard Favicon / Web Icons**
   - `favicon.ico` (multi-resolution: 16x16, 32x32, 48x48, 64x64).
   - PNG icons:
     - 16x16
     - 32x32
     - 48x48
     - 64x64
     - 128x128
     - 256x256 (optional)

3. **Apple / Mobile Icons**
   - Apple touch icons (PNG; although spec doesn’t require SVG, we can derive PNGs from the SVG canonical):
     - 120x120
     - 152x152
     - 167x167
     - 180x180
   - Android/Chrome icons (PNG):
     - 192x192
     - 512x512

4. **SVG Variants**
   - Base SVG (single canonical export).
   - Optionally, size-agnostic (the same SVG works for multiple sizes).

---

### 2.3 Canvas Editor Feature Set (MS-Paint-Level)

Minimum features:

- **Canvas**
  - Fixed default size (e.g. 256x256 or 512x512) with grid overlay.
  - Zoom in/out (few steps).
- **Drawing tools**
  - Pencil / brush (1–3 line widths).
  - Eraser.
  - Line tool.
  - Rectangle and ellipse (outline + filled).
  - Paint bucket (flood fill).
  - Text tool (basic text placement).
- **Color & style**
  - Color picker (palette + custom via hex/RGB).
  - Background color fill.
- **Editing**
  - Undo/redo (basic stack).
  - Clear canvas.
- **Export**
  - Convert canvas drawing into SVG (vector representation where possible, or raster-packed into SVG).
  - Send result to backend for processing.

---

## 3. Non-Functional Requirements

- **Performance**
  - Single favicon generation (including resizing) should complete within ~1–3 seconds for typical images.
  - Directory page should render within ~200–500 ms for backend and be paginated.
- **Scalability**
  - Stateless backend (NestJS) with object storage for icons and a managed DB for metadata.
  - Horizontal scaling via containers.
- **Reliability**
  - All generated assets should be stored durably (e.g., DO Spaces).
  - Idempotent generation endpoints (re-generating same favicon with same input and domain should not create duplicates unless requested).
- **Security**
  - Hardened Docker images.
  - Strict file type and size validation.
  - No execution of untrusted code.
- **Observability**
  - Basic application logs.
  - Metrics for number of favicons generated, errors, request latencies.

---

## 4. High-Level Architecture

### 4.1 Components

1. **Frontend (Angular)**
   - SPA served via Node or static file server.
   - Features:
     - Landing page
     - Upload flow
     - Canvas editor
     - Favicon detail view
     - Directory
   - Communicates with backend via REST APIs.

2. **Backend (NestJS)**
   - REST API.
   - Modules (initially):
     - `FaviconModule` – core generation, storage, retrieval.
     - `DirectoryModule` – listing, sorting, searching.
     - `StorageModule` – abstraction for object storage (local vs DO Spaces).
     - `HealthModule` – health checks, info.
   - Uses DI heavily (Nest providers) with functional-style business logic functions.

3. **Data Storage**
   - **Relational DB** (e.g. PostgreSQL on DO Managed DB) for metadata:
     - Favicon records
     - Generated assets metadata
   - **Object Storage** (e.g. DO Spaces):
     - Binary assets: `.ico`, `.png`, `.svg`.

4. **Infrastructure**
   - Local: `docker-compose` to run:
     - Angular app
     - NestJS API
     - Postgres
     - MinIO (or local storage) to emulate Spaces.
   - Production:
     - Terraform-managed:
       - DO Managed Postgres
       - DO Spaces bucket
       - DO Droplet or App Platform for running Docker images
       - Firewalls, load balancer, DNS records.

---

## 5. Data Model

### 5.1 Core Entities

1. **Favicon**
   - `id` (UUID or snowflake)
   - `slug` (URL-safe unique identifier, e.g., `my-cool-icon-123abc`)
   - `title` (optional)
   - `target_domain` (e.g. `example.com`)
   - `published_url` (computed or manually set, e.g. `https://a-icon.com/f/my-cool-icon`)
   - `canonical_svg_key` (reference to object storage key)
   - `source_type` (enum: `UPLOAD`, `CANVAS`)
   - `source_original_mime` (e.g. `image/png`, `image/jpeg`, `image/svg+xml`)
   - `is_published` (boolean; controls directory visibility)
   - `created_at`
   - `updated_at`
   - `generated_at` (when generation completed)
   - `generation_status` (`PENDING`, `SUCCESS`, `FAILED`)
   - `generation_error` (nullable text)

2. **FaviconAsset**
   - `id`
   - `favicon_id` (FK to Favicon)
   - `type` (e.g. `ICO`, `PNG`, `SVG`)
   - `size` (nullable; e.g. `16x16`, `192x192`, `MULTI`, etc.)
   - `format` (e.g. `.ico`, `.png`, `.svg`)
   - `storage_key` (object storage key)
   - `mime_type`
   - `created_at`

### 5.2 Indexing / Sorting Support

- Indexes:
  - `Favicon.created_at`
  - `Favicon.published_url`
  - `Favicon.target_domain`
  - Composite indexes as needed for sorting queries.
- Directory queries:
  - Filters on `is_published = true`.
  - `ORDER BY` field based on user selection.

---

## 6. API Design (NestJS)

All endpoints under `/api`.

### 6.1 Favicon Generation & Retrieval

1. `POST /api/favicons/upload`
   - **Purpose**: Upload an image and trigger favicon generation.
   - Request:
     - Multipart form data:
       - `file`: image file (PNG/JPEG/SVG).
       - `targetDomain`: string (optional).
       - `title`: string (optional).
       - `publish`: boolean (default false/true as desired).
   - Response:
     - `faviconId`, `slug`, `publishedUrl`, `status`.

2. `POST /api/favicons/canvas`
   - **Purpose**: Submit canvas-created icon (SVG or drawing model).
   - Request:
     - JSON body:
       - `svgData`: string (SVG markup) OR `drawingModel`: structured drawing instructions.
       - `targetDomain`, `title`, `publish` (same as above).
   - Response: same as upload.

3. `GET /api/favicons/:slug`
   - **Purpose**: Retrieve favicon metadata and asset descriptors.
   - Response:
     - `favicon` metadata
     - List of assets (size, type, download URL).

4. `GET /api/favicons/:slug/assets/:assetId`
   - **Purpose**: Download specific asset (or redirect to object storage URL).
   - Implementation:
     - Either proxy data streaming from object storage.
     - Or redirect (signed URL if private; likely public-read for simplicity).

5. `POST /api/favicons/:slug/regenerate` (optional)
   - **Purpose**: Regenerate assets, e.g., after template changes.
   - Idempotent: same inputs → same outputs/keys.

### 6.2 Directory Listing

1. `GET /api/directory`
   - Query params:
     - `page` (int, default 1)
     - `pageSize` (int, default 20, max 100)
     - `sortBy` (`date`, `url`, `domain`)
     - `sortDir` (`asc`, `desc`)
     - Optional filters (future).
   - Response:
     - `items`: list of published favicons with key metadata and thumbnail URL.
     - `total`, `page`, `pageSize`.

### 6.3 Health & Info

1. `GET /api/health`
   - DB, storage, and basic checks.

---

## 7. Favicon Generation Pipeline

### 7.1 Core Steps

For **uploaded images**:

1. Validate input:
   - Check MIME type and extension.
   - Check file size.
   - Attempt to decode via image library (e.g. Sharp).
2. Normalize:
   - Resize or fit into canonical square (e.g., 512x512) with optional background color.
3. Create canonical SVG:
   - If original is SVG:
     - Sanitize (remove scripts, embeds).
     - Normalize viewBox.
   - If raster:
     - Embed PNG in SVG `<image>` or auto-trace if simple (optional/future).
4. Generate derivatives:
   - Use image processing pipeline (e.g., Sharp + ICO helper) to:
     - Generate PNG in all required sizes.
     - Generate ICO container with multiple resolutions.
5. Store:
   - Upload canonical SVG and each derivative to object storage with stable keys (e.g. `favicons/{id}/favicon.ico`, `favicons/{id}/icons/icon-16x16.png`, etc.).
   - Save metadata records in DB.
6. Respond:
   - Return new favicon object and accessible URLs.

For **canvas-generated icons**:

- Skip upload/validation, as we own the SVG content.
- Same steps from canonical SVG onward.

### 7.2 Functional & Idempotent Design

- Favicon generation logic implemented as a **pure function** where possible:
  - Inputs: canonical image/parameters.
  - Outputs: buffers for each asset + metadata.
- A thin service layer (Nest provider) orchestrates:
  - DB writes
  - Storage writes
  - Logging
- Idempotency:
  - Use a deterministic `slug` / asset key pattern when regenerating from the same `faviconId`.
  - Optionally, detect identical input images (hash) to avoid duplicates.

---

## 8. Angular Frontend Design

### 8.1 Structure

- Angular workspace with modules:
  - `CoreModule` – services (API client, config).
  - `SharedModule` – common components.
  - Feature modules:
    - `HomeModule` – landing page + quick upload.
    - `CanvasModule` – editor.
    - `FaviconModule` – detail view.
    - `DirectoryModule` – listing.

### 8.2 Pages

1. **Home / Landing**
   - Overview of service.
   - Upload widget.
   - Button “Create from scratch”.

2. **Canvas Editor**
   - Toolbar (tools, color picker, undo/redo).
   - Canvas area.
   - Size indicator.
   - Buttons:
     - “Preview”
     - “Generate & Publish”

3. **Favicon Detail**
   - Preview grid of sizes.
   - Download links.
   - Quick copy of HTML snippet:
     - `<link rel="icon" …>`
     - `<link rel="apple-touch-icon" …>`
   - Metadata display.
   - Option to toggle published state (future, if accounts added).

4. **Directory**
   - Paginated table or card grid.
   - Sort controls.
   - Search/filter box (future).
   - Links to favicon detail pages.

### 8.3 Client–Server Interaction

- Angular `HttpClient` service wrappers:
  - `FaviconApiService` for `/api/favicons/*`.
  - `DirectoryApiService` for `/api/directory`.
- Centralized error handling and loading indicators.
- Strongly typed responses (TypeScript interfaces).

---

## 9. Directory Implementation Details

### 9.1 Backend

- `DirectoryService`:
  - Accepts parameters: page, pageSize, sortBy, sortDir.
  - Builds DB query with:
    - `WHERE is_published = true`.
    - `ORDER BY`:
      - `created_at` when sortBy = `date`.
      - `published_url` when `url`.
      - `target_domain` when `domain`.
  - Paginates via `OFFSET/LIMIT` or keyset pagination (future improvement).

### 9.2 Frontend

- Directory component:
  - Reactive state:
    - `currentPage`, `pageSize`, `sortBy`, `sortDir`.
  - On user interactions (change sort, next page) → API call.
  - Displays:
    - Thumbnail (small PNG or SVG).
    - Title, domain, URL, publish date.

---

## 10. Security & Hardening

### 10.1 Application-Level Security

- **Input Validation**
  - Enforce allowed MIME types and file extensions.
  - Enforce size limit; return 413 if too large.
  - Sanitize user-provided strings (title, domain).
- **SVG Sanitization**
  - Strip script tags, event handlers, foreignObject, and external resource references.
  - Use whitelist of SVG elements and attributes.
- **Rate Limiting**
  - IP-based rate limiting on generation endpoints.
- **CSRF/XSS Protection**
  - CSRF protection (if cookies used; for a simple stateless API, use token-based or no auth at start).
  - Angular automatically escapes template data.
  - Set content security policy (CSP) headers.
- **Headers & CORS**
  - Appropriate CORS settings (allow Angular origin).
  - Security headers via Nest middleware:
    - `X-Content-Type-Options: nosniff`
    - `X-Frame-Options: DENY`
    - `Strict-Transport-Security` (in production).
- **Authentication/Authorization** (Phase 2+)
  - Initial MVP can be anonymous usage, with rate limits.
  - Later we can add accounts and private icons.

### 10.2 Docker Hardening

- Multi-stage builds:
  - Stage 1: build Angular and NestJS.
  - Stage 2: minimal runtime image (e.g., distroless or slim Node image).
- Security practices:
  - Run as non-root user.
  - Limit file system to read-only where possible.
  - Only expose required ports.
  - Avoid bundling build tools into runtime image.
  - Use environment variables for secrets; no secrets in image.
  - Add healthcheck in Dockerfile.
- Use `docker-compose` locally to:
  - Run backend, frontend, DB, storage (MinIO) in isolated network.
  - Confirm correct port mappings and network policies.

### 10.3 Infrastructure & Terraform

- Terraform modules/resources on DigitalOcean:
  - VPC and firewalls:
    - Restrict DB access to app nodes.
  - DO Managed PostgreSQL:
    - Private network only.
    - Strong passwords.
  - DO Spaces bucket:
    - Bucket for favicon assets.
    - Appropriate ACL / public-read policy for assets (or presigned URLs).
  - Droplets or App Platform services:
    - Deploy Docker images from registry (e.g., DOCR).
  - DNS:
    - `a-icon.com` pointing to load balancer or app endpoint.
- Terraform outputs:
  - DB connection string.
  - Spaces endpoint and credentials (using DO API keys stored securely).

---

## 11. Observability & Operations

- **Logging**
  - Structured logs (JSON) from NestJS and Angular server (if SSR).
  - Log:
    - Incoming requests (path, status, latency).
    - Generation jobs (started/completed/failed).
- **Metrics**
  - Basic counters:
    - `favicons_generated_total`
    - `generation_failures_total`
  - Latency histograms.
- **Monitoring**
  - Health check endpoint integrated with load balancer.
  - Alerts on high error rates or DB/storage connectivity issues.

---

## 12. Implementation Phases & Checklist

This is the actionable checklist derived from the plan.

### Phase 0 – Project Scaffolding

1. Initialize monorepo or separate repos:
   - Angular app (`a-icon-web`).
   - NestJS API (`a-icon-api`).
2. Set up TypeScript, linting, and formatting.
3. Add base Dockerfiles for backend and frontend.
4. Add `docker-compose.yml` for local development:
   - API, web, Postgres, MinIO.

### Phase 1 – Backend Foundations (NestJS)

1. Scaffold NestJS project and modules:
   - `FaviconModule`, `DirectoryModule`, `StorageModule`, `HealthModule`.
2. Integrate database:
   - Choose ORM (e.g., TypeORM/Prisma).
   - Create migrations for `Favicon` and `FaviconAsset` tables.
3. Implement `StorageService` interface:
   - Local filesystem/MinIO implementation for development.
4. Implement `HealthController` and health checks.

### Phase 2 – Favicon Generation Engine

1. Choose image processing stack (e.g., Sharp + ICO helper).
2. Implement pure generation functions:
   - Input: canonical image data.
   - Output: buffers for all desired icon sizes + metadata.
3. Implement upload endpoint (`POST /api/favicons/upload`):
   - File upload handling.
   - Validation.
   - Call generation engine.
   - Store assets and metadata.
4. Implement retrieval endpoint (`GET /api/favicons/:slug`).
5. Implement asset serving (`GET /api/favicons/:slug/assets/:assetId`).

### Phase 3 – Canvas Editor Integration

1. Implement Angular canvas editor UI and tools.
2. Export editor contents as SVG/drawing model.
3. Implement `POST /api/favicons/canvas` endpoint.
4. Integrate editor flow with backend, then redirect to favicon detail page.

### Phase 4 – Directory & Sorting

1. Implement `DirectoryService` and `/api/directory` endpoint:
   - Support sorting by date, URL, domain.
   - Pagination.
2. On frontend, implement directory page:
   - Table/grid.
   - Controls for pagination and sorting.
3. Ensure only `is_published = true` favicons appear.

### Phase 5 – Frontend Polish & UX

1. Build landing page and integrate upload widget.
2. Implement favicon detail page:
   - Preview, downloads, snippets.
3. Add error states, loading spinners, basic styling.

### Phase 6 – Security & Hardening

1. Enforce all validation and sanitization rules.
2. Add rate limiting in NestJS.
3. Harden CORS and security headers.
4. Finalize Docker hardening:
   - Non-root, minimal runtime images, health checks.

### Phase 7 – Terraform & Deployment

1. Write Terraform configurations for:
   - DigitalOcean VPC, firewall, Droplet/App Platform.
   - Managed Postgres, Spaces, DNS.
2. Configure CI pipeline:
   - Build & push Docker images.
   - Run tests.
   - Optionally, trigger Terraform apply.
3. Deploy to DigitalOcean environment.
4. Run smoke tests:
   - Health endpoint.
   - Upload and generate sample favicon.
   - Verify directory listing and sorting.


