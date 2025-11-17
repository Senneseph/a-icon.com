# Multi-stage Dockerfile for a-icon-web (Angular SSR)

# Builder stage
FROM cgr.dev/chainguard/node:latest AS builder

ARG API_URL=http://localhost:3000
ENV API_URL=$API_URL

WORKDIR /usr/src/app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source
COPY . ./

# Replace BOTH environment files with production values
RUN echo "export const environment = { production: true, apiUrl: '$API_URL' };" > src/environments/environment.prod.ts && \
    echo "export const environment = { production: true, apiUrl: '$API_URL' };" > src/environments/environment.ts

# Build
RUN npm run build

# Production stage
FROM cgr.dev/chainguard/node:latest AS production

ENV NODE_ENV=production
WORKDIR /usr/src/app

# Install only production dependencies needed at runtime
COPY package*.json ./
RUN npm ci --omit=dev && npm cache clean --force

# Copy built Angular app (browser + server bundles)
COPY --from=builder /usr/src/app/dist ./dist

# Non-root user (use existing users group GID 100)
RUN adduser -u 1001 -G users -s /bin/sh -D appuser
USER appuser

# Angular SSR server default port
ENV PORT=4000
EXPOSE 4000

CMD ["node", "dist/a-icon-web/server/server.mjs"]

