# a-icon.com

A modern favicon generator and management platform built with Angular and NestJS.

## 🎯 Overview

a-icon.com is a web service that allows users to:

- **Upload images** and convert them into multi-size favicon sets (`.ico`, `.png`)
- **Create favicons from scratch** using a built-in drawing canvas
- **Browse a directory** of published favicons with sorting options
- **Get unique URLs** for each generated favicon set

## 🏗️ Architecture

### Tech Stack

- **Frontend**: Angular 20 with Server-Side Rendering (SSR)
- **Backend**: NestJS 11 with TypeScript
- **Database**: SQLite (better-sqlite3)
- **Image Processing**: Sharp
- **Containerization**: Docker & Docker Compose
- **Infrastructure**: DigitalOcean (Terraform)

### Project Structure

```
a-icon.com/
├── a-icon-api/          # NestJS backend API
│   ├── src/
│   │   ├── favicon/     # Favicon generation & management
│   │   ├── storage/     # File storage service
│   │   ├── directory/   # Directory listing
│   │   └── database/    # SQLite database module
│   └── Dockerfile
├── a-icon-web/          # Angular frontend with SSR
│   ├── src/
│   │   ├── app/
│   │   │   ├── upload/      # Upload component
│   │   │   └── directory/   # Directory listing component
│   │   └── server.ts        # SSR Express server
│   └── Dockerfile
├── terraform/           # Infrastructure as Code
├── docker-compose.yml   # Local development
└── docker-compose.prod.yml  # Production deployment
```

## 🚀 Quick Start

### Prerequisites

- Node.js 22.12+
- Docker & Docker Compose
- Git

### Local Development

1. **Clone the repository**
   ```bash
   git clone https://github.com/Senneseph/a-icon.com.git
   cd a-icon.com
   ```

2. **Start the services**
   ```bash
   docker-compose up
   ```

3. **Access the application**
   - Web: http://localhost:4200
   - API: http://localhost:3000
   - Directory: http://localhost:4200/directory

### Development Without Docker

**Backend (API)**
```bash
cd a-icon-api
npm install
npm run start:dev
```

**Frontend (Web)**
```bash
cd a-icon-web
npm install
npm start
```

## 📦 Deployment

### Production Deployment to DigitalOcean

1. **Set up environment variables**
   ```bash
   # Create .env file (not tracked in git)
   DO_TOKEN="your_digitalocean_token"
   ```

2. **Deploy from GitHub**
   ```powershell
   .\deploy-from-github.ps1
   ```

This script will:
- Clone the repository on the droplet
- Build Docker images on the server
- Start the containers with production configuration

### Manual Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed deployment instructions.

## 🔧 Configuration

### Environment Variables

**API (a-icon-api)**
- `NODE_ENV`: Environment (development/production)
- `PORT`: API port (default: 3000)
- `DB_PATH`: SQLite database file path
- `STORAGE_ROOT`: File storage directory

**Web (a-icon-web)**
- `NODE_ENV`: Environment (development/production)
- `PORT`: Web server port (default: 4000)
- `API_URL_SSR`: Server-side API URL for SSR (e.g., `http://api:3000`)

## 🧪 Testing

**API Tests**
```bash
cd a-icon-api
npm test
npm run test:e2e
```

**Web Tests**
```bash
cd a-icon-web
npm test
```

## 📝 API Endpoints

### Favicon Management
- `POST /api/favicons/upload` - Upload image and generate favicon
- `POST /api/favicons/canvas` - Create favicon from canvas data
- `GET /api/favicons/:slug` - Get favicon metadata

### Directory
- `GET /api/directory` - List all favicons (supports sorting)
  - Query params: `sortBy` (createdAt/slug), `order` (asc/desc)

### Storage
- `GET /api/storage/*` - Serve generated favicon files

### Health
- `GET /api/health` - Health check endpoint

## 🐳 Docker

### Build Images
```bash
docker-compose build
```

### Production Build
```bash
docker-compose -f docker-compose.prod.yml build
```

## 🔐 Security

- All services run in hardened Docker containers
- Non-root users in containers
- Environment-based configuration (no hardcoded secrets)
- Input validation and sanitization
- CORS configuration

## 📄 License

UNLICENSED - Private project

## 👤 Author

Benjamin Hill (Senneseph)

## 🔗 Links

- **Repository**: https://github.com/Senneseph/a-icon.com
- **Production**: http://a-icon.com/

