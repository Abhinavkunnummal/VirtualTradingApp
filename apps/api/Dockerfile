# Multi-stage production Dockerfile for TradeVerse AI Node.js API
FROM node:20-alpine AS builder

WORKDIR /app

# Install build dependencies
COPY package*.json tsconfig.json ./
RUN npm ci

# Copy source code and compile TypeScript to JavaScript
COPY src ./src
RUN npm run build

# Stage 2: Production runtime image
FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5000

# Install production dependencies only
COPY package*.json ./
RUN npm ci --only=production && npm cache clean --force

# Copy compiled output from builder
COPY --from=builder /app/dist ./dist

# Security best practice: Run as unprivileged user
USER node

EXPOSE 5000

CMD ["node", "dist/server.js"]
