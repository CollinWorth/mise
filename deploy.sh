#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

step() { echo -e "${CYAN}==>${NC} $1"; }
ok()   { echo -e "${GREEN}✓${NC} $1"; }
err()  { echo -e "${RED}✗ ERROR:${NC} $1"; exit 1; }

PROJECT_DIR="${HOME}/mise"
cd "$PROJECT_DIR" || err "Could not cd into $PROJECT_DIR"

# ─── 1. Pull latest code ───────────────────────────────────────────────────────
step "Pulling latest code..."
git pull
ok "Code up to date"

# ─── 2. Backend (Python / FastAPI) ────────────────────────────────────────────
step "Updating backend dependencies..."

if [ -d "backend/venv" ]; then
  source backend/venv/bin/activate
elif [ -d "backend/.venv" ]; then
  source backend/.venv/bin/activate
elif [ -d ".venv" ]; then
  source .venv/bin/activate
else
  echo "  No venv found — using system Python"
fi

if [ -f "backend/requirements.txt" ]; then
  pip install -r backend/requirements.txt -q
elif [ -f "backend/pyproject.toml" ]; then
  pip install -e backend/ -q
else
  err "No requirements.txt or pyproject.toml found in backend/"
fi

ok "Backend deps installed"

# ─── 3. Frontend (React) ──────────────────────────────────────────────────────
step "Building frontend..."

if [ -f "frontend/package.json" ]; then
  cd frontend
elif [ -f "package.json" ]; then
  : # stay in root
else
  err "No package.json found"
fi

npm install --silent
npm run build
cd "$PROJECT_DIR"

ok "Frontend built"

# ─── 4. Restart backend service ───────────────────────────────────────────────
step "Restarting backend..."

if command -v pm2 &>/dev/null; then
  pm2 restart api && ok "PM2 process restarted"
elif systemctl is-active --quiet mise-api 2>/dev/null; then
  sudo systemctl restart mise-api && ok "systemd service restarted"
else
  echo "  ⚠️  No PM2 or known systemd service found — restart your backend manually"
fi

# ─── 5. Reload nginx ──────────────────────────────────────────────────────────
step "Reloading nginx..."
if systemctl is-active --quiet nginx 2>/dev/null; then
  sudo systemctl reload nginx && ok "nginx reloaded"
else
  echo "  ⚠️  nginx not running — skipping"
fi

echo ""
echo -e "${GREEN}🚀 Deploy complete!${NC}"
