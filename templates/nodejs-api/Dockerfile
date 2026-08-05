# ─── Build stage ────────────────────────────────────────────────
FROM node:20-alpine AS build
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .

# ─── Runtime stage (non-root, fail-securely) ───────────────────
# Lý do:
#   - Chạy non-root (USER app) → nếu bị RCE, attacker không có quyền root
#   - dumb-init → nhận signal đúng để pod graceful shutdown khi scale/rollout
#   - Chỉ copy phần đã build, không kéo node_modules dev vào image
FROM node:20-alpine
ENV NODE_ENV=production \
    PORT=8080
WORKDIR /app
RUN apk add --no-cache dumb-init && \
    addgroup -S app && adduser -S app -G app
COPY --from=build /app ./
USER app
EXPOSE 8080
ENTRYPOINT ["dumb-init", "--"]
CMD ["node", "src/index.js"]
