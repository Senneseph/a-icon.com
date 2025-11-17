# Multi-stage Dockerfile for a-icon-api (NestJS)

# Builder stage
FROM node:24-alpine AS builder

# Install build dependencies for native modules and curl for health checks
RUN apk add --no-cache python3 make g++ curl

WORKDIR /usr/src/app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source and build
COPY . ./
RUN npm run build

# Production stage
FROM node:24-alpine AS production

# Install build dependencies for native modules and curl for health checks
RUN apk add --no-cache python3 make g++ curl

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
