# Production Dockerfile for TradeVerse AI API (Monorepo root)
FROM node:20-alpine AS builder

WORKDIR /app

COPY apps/api/package*.json apps/api/tsconfig.json ./
RUN npm ci

COPY apps/api/src ./src
RUN npm run build

FROM node:20-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=5000

COPY apps/api/package*.json ./
RUN npm ci --only=production && npm cache clean --force

COPY --from=builder /app/dist ./dist

USER node

EXPOSE 5000

CMD ["node", "dist/server.js"]
