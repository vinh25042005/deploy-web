## BUILD ##
FROM node:26-alpine AS build


# Đã chuyển sang dùng apk của Alpine thay vì apt-get
RUN apk add --no-cache openssl
WORKDIR /build

COPY frontend/package*.json ./
RUN npm ci

# Backend internal URL để Next.js rewrites proxy /api/*
ARG BACKEND_INTERNAL_URL=http://localhost:3001
ENV BACKEND_INTERNAL_URL=$BACKEND_INTERNAL_URL

COPY frontend/ ./
RUN npm run build

# ─── Dọn dev dependencies (tailwind, postcss, typescript...) ───
RUN npm prune --production

## RUN ##
FROM node:26-alpine

LABEL org.opencontainers.image.title="TechShop Frontend"
LABEL org.opencontainers.image.version="1.0.0"

RUN apk upgrade --no-cache && adduser -D frontend
RUN npm install -g npm@latest

# Backend internal URL cho Next.js rewrites (cần ở runtime)
ENV BACKEND_INTERNAL_URL=http://10.20.1.3:3001

WORKDIR /app
COPY --from=build --chown=frontend:frontend /build/package*.json ./
COPY --from=build --chown=frontend:frontend /build/.next ./.next
COPY --from=build --chown=frontend:frontend /build/node_modules ./node_modules

USER frontend

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000 || exit 1

CMD ["npm", "run", "start"]