# Google Calendar MCP Server - Optimized Dockerfile with multi-stage build
# syntax=docker/dockerfile:1

# Build stage
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files for dependency caching
COPY package*.json ./

# Copy build files
COPY scripts ./scripts
COPY src ./src
COPY tsconfig.json .

# Install all dependencies and build (with retries for transient network issues)
RUN set -eux; \
    attempts=5; \
    i=1; \
    while [ "$i" -le "$attempts" ]; do \
        if npm ci --no-audit --no-fund --silent && npm run build && npm prune --production --silent; then \
            break; \
        fi; \
        if [ "$i" -eq "$attempts" ]; then \
            exit 1; \
        fi; \
        echo "npm build failed ($i/$attempts), retrying in 5s..."; \
        i=$((i + 1)); \
        sleep 5; \
    done

# Runtime stage
FROM node:18-alpine

# Create app user for security
RUN addgroup -g 1001 -S nodejs && \
    adduser -S -u 1001 -G nodejs nodejs

WORKDIR /app

# Copy only production files from builder
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/build ./build
COPY --from=builder /app/package*.json ./

# Create config directory and set permissions
RUN mkdir -p /home/nodejs/.config/google-calendar-mcp && \
    chown -R nodejs:nodejs /home/nodejs/.config /app

USER nodejs

# Expose ports for HTTP mode and OAuth callback (optional)
EXPOSE 3000 3500 3501 3502 3503 3504 3505

# НЕ устанавливаем CMD - будет переопределен в docker-compose.yml
# Контейнер будет работать в режиме sleep infinity для docker exec
