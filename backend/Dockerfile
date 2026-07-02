## BUILD ##
FROM node:24 AS build

RUN apt-get update && apt-get install -y openssl

WORKDIR /build

COPY backend/package*.json ./
COPY database ./database

RUN npm ci
RUN npx prisma generate --schema=./database/prisma/schema.prisma

COPY backend/ ./
RUN npm run build

# ─── Dọn dev dependencies, giữ lại production modules ───
RUN npm prune --production

## RUN ##
FROM node:24-alpine

LABEL org.opencontainers.image.title="TechShop Backend"
LABEL org.opencontainers.image.version="1.0.0"

RUN apk upgrade --no-cache && adduser -D backend
RUN apk add --no-cache openssl curl

WORKDIR /app
COPY --from=build --chown=backend:backend /build/dist ./dist
COPY --from=build --chown=backend:backend /build/node_modules ./node_modules
COPY --from=build --chown=backend:backend /build/package*.json ./
COPY --from=build --chown=backend:backend /build/database ./database

USER backend

EXPOSE 3001

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:3001/api/health || exit 1

CMD ["node", "dist/index.js"]