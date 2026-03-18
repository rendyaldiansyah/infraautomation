#!/usr/bin/env bash
# ============================================================
#  generate-lockfiles.sh
#  Generate package-lock.json untuk frontend dan API.
#
#  Jalankan SEKALI di mesin lokal sebelum push ke GitHub.
#  File ini harus di-commit agar Docker build dan CI/CD berjalan.
#
#    chmod +x generate-lockfiles.sh
#    ./generate-lockfiles.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log()  { echo -e "${CYAN}[>>]${NC} $1"; }
warn() { echo -e "${YELLOW}[!!]${NC} $1"; }
die()  { echo -e "${RED}[ERR]${NC} $1"; exit 1; }

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "\n${BOLD}╔══════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║  Generate package-lock.json — LKS 2026      ║${NC}"
echo -e "${BOLD}╚══════════════════════════════════════════════╝${NC}\n"

# Check prerequisites
command -v node &>/dev/null || die "Node.js tidak terinstal — install dari https://nodejs.org"
command -v npm  &>/dev/null || die "npm tidak terinstal"
ok "Node.js: $(node --version), npm: $(npm --version)"

# ── Frontend ─────────────────────────────────────────────────
echo ""
log "Generate frontend/package-lock.json ..."

cd "$ROOT_DIR/frontend"
if [ -f package-lock.json ]; then
  warn "frontend/package-lock.json sudah ada — skip (hapus dulu jika ingin regenerate)"
else
  # Generate lock file without installing to node_modules (npm >= 6)
  npm install --package-lock-only 2>/dev/null \
    || npm install  # fallback: full install jika versi lama
  ok "frontend/package-lock.json dibuat"
fi

# Remove node_modules dari git — tidak perlu di-commit
[ -d node_modules ] && {
  warn "Menghapus frontend/node_modules dari git tracking (jika ada)..."
  git -C "$ROOT_DIR" rm -r --cached node_modules/ 2>/dev/null || true
}

# ── API ──────────────────────────────────────────────────────
echo ""
log "Generate api/package-lock.json ..."

cd "$ROOT_DIR/api"
if [ -f package-lock.json ]; then
  warn "api/package-lock.json sudah ada — skip"
else
  npm install --package-lock-only 2>/dev/null \
    || npm install
  ok "api/package-lock.json dibuat"
fi

[ -d node_modules ] && {
  warn "Menghapus api/node_modules dari git tracking (jika ada)..."
  git -C "$ROOT_DIR" rm -r --cached node_modules/ 2>/dev/null || true
}

cd "$ROOT_DIR"

# ── Verify & commit ──────────────────────────────────────────
echo ""
log "Verifikasi file yang dibuat..."

FE_LOCK="$ROOT_DIR/frontend/package-lock.json"
API_LOCK="$ROOT_DIR/api/package-lock.json"

[ -f "$FE_LOCK" ]  && ok "frontend/package-lock.json ✓ ($(wc -c < "$FE_LOCK" | tr -d ' ') bytes)" \
                   || die "frontend/package-lock.json tidak dibuat"
[ -f "$API_LOCK" ] && ok "api/package-lock.json ✓ ($(wc -c < "$API_LOCK" | tr -d ' ') bytes)" \
                   || die "api/package-lock.json tidak dibuat"

# Auto-commit jika di dalam git repo
if git -C "$ROOT_DIR" rev-parse --git-dir &>/dev/null; then
  echo ""
  log "Commit package-lock.json ke git..."
  git -C "$ROOT_DIR" add frontend/package-lock.json api/package-lock.json
  git -C "$ROOT_DIR" status --short
  git -C "$ROOT_DIR" commit -m "Add package-lock.json for frontend and API" \
    2>/dev/null && ok "Committed" || warn "Tidak ada perubahan untuk di-commit (mungkin sudah up-to-date)"
  echo ""
  echo -e "${CYAN}Sekarang push ke GitHub:${NC}"
  echo -e "  git push origin main"
else
  echo ""
  echo -e "${YELLOW}Manual steps:${NC}"
  echo -e "  git add frontend/package-lock.json api/package-lock.json"
  echo -e "  git commit -m 'Add package-lock.json'"
  echo -e "  git push origin main"
fi

echo ""
echo -e "${GREEN}${BOLD}Selesai! Docker build dan CI/CD sudah bisa berjalan.${NC}\n"
