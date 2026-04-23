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

# ─── 4. Restart services ──────────────────────────────────────────────────────
step "Restarting services..."

if command -v pm2 &>/dev/null; then
  # Activate venv so pip installs land correctly, then restart via PM2
  VENV_UVICORN=""
  for p in backend/venv backend/.venv .venv; do
    if [ -f "$p/bin/uvicorn" ]; then
      VENV_UVICORN="$(pwd)/$p/bin/uvicorn"
      break
    fi
  done

  if pm2 describe api &>/dev/null; then
    pm2 restart api && ok "Backend restarted"
  elif [ -n "$VENV_UVICORN" ]; then
    pm2 start "$VENV_UVICORN main:app --host 0.0.0.0 --port 8000" --name api --cwd "$(pwd)/backend"
    pm2 save && ok "Backend started"
  else
    err "Could not find uvicorn in venv — activate your venv and run: pm2 start \"\$(which uvicorn) main:app --host 0.0.0.0 --port 8000\" --name api --cwd ~/mise/backend"
  fi
  pm2 restart frontend && ok "Frontend restarted"
else
  err "PM2 not found — run: npm install -g pm2"
fi

echo ""
echo -e "${GREEN}🚀 Deploy complete!${NC}"
