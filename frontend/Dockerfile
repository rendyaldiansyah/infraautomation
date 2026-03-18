# ── Stage 1: Build ──────────────────────────────────────────
FROM node:18-alpine AS builder

WORKDIR /app

# Copy package files
# npm install (not ci) because package-lock.json may not exist yet
COPY package*.json ./
RUN npm install

# Copy source and build
COPY . .
RUN npm run build

# ── Stage 2: Serve ──────────────────────────────────────────
# Minimal Nginx Alpine — no Node.js in the final image
FROM nginx:alpine

COPY --from=builder /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup \
  && chown -R appuser:appgroup /usr/share/nginx/html \
  && chown -R appuser:appgroup /var/cache/nginx \
  && chown -R appuser:appgroup /var/log/nginx \
  && touch /var/run/nginx.pid \
  && chown appuser:appgroup /var/run/nginx.pid

USER appuser
EXPOSE 3000
CMD ["nginx", "-g", "daemon off;"]
