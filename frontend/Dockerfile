## BUILD ##
FROM node:20 AS build

WORKDIR /build

COPY frontend/package*.json ./
RUN npm ci

ARG NEXT_PUBLIC_API_URL=http://localhost:3001/api
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL

COPY frontend/ ./
RUN npm run build

# ─── Dọn dev dependencies (tailwind, postcss, typescript...) ───
RUN npm prune --production

## RUN ##
FROM node:20-alpine

LABEL org.opencontainers.image.title="TechShop Frontend"
LABEL org.opencontainers.image.version="1.0.0"

RUN apk upgrade --no-cache && adduser -D frontend

WORKDIR /app
COPY --from=build --chown=frontend:frontend /build/package*.json ./
COPY --from=build --chown=frontend:frontend /build/.next ./.next
COPY --from=build --chown=frontend:frontend /build/node_modules ./node_modules

USER frontend

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000 || exit 1

CMD ["npm", "run", "start"]