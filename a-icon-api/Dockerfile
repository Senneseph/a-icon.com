# Multi-stage Dockerfile for a-icon-api (NestJS)

# Builder stage - use dev variant with build tools
FROM cgr.dev/chainguard/node:latest-dev AS builder

WORKDIR /usr/src/app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . ./
RUN npm run build

# Production stage - use dev variant for native module support
FROM cgr.dev/chainguard/node:latest-dev AS production

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Install only production dependencies
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy built application
COPY --from=builder /usr/src/app/dist ./dist

# Create data directory for SQLite and storage
RUN mkdir -p /usr/src/app/data/storage

EXPOSE 3000

CMD ["node", "dist/main.js"]
