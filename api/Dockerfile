# ── Stage 1: Install dependencies ───────────────────────────
FROM node:18-alpine AS deps
WORKDIR /app
COPY package*.json ./
# npm install (not ci) — generates lock file if absent, installs prod deps
RUN npm install --only=production

# ── Stage 2: Runtime ────────────────────────────────────────
FROM node:18-alpine
WORKDIR /app

COPY --from=deps /app/node_modules ./node_modules
COPY src/ ./src/
COPY package.json ./

RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

EXPOSE 8080
EXPOSE 9100
ENV NODE_ENV=production

CMD ["node", "src/index.js"]
