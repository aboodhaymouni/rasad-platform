#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────
#  RASAD — One-command Hostinger VPS deployment
#  Run on a fresh Ubuntu 22.04 VPS as root or sudo user.
#
#  Usage:
#    curl -fsSL https://raw.githubusercontent.com/aboodhaymouni/rasad-platform/main/deploy.sh | bash
#  Or after cloning:
#    chmod +x deploy.sh && ./deploy.sh
# ─────────────────────────────────────────────────────────────────

set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/aboodhaymouni/rasad-platform.git}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/rasad-platform}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

say()   { printf "${BLUE}▶${NC} %s\n" "$*"; }
ok()    { printf "${GREEN}✓${NC} %s\n" "$*"; }
warn()  { printf "${YELLOW}⚠${NC} %s\n" "$*"; }
fail()  { printf "${RED}✗${NC} %s\n" "$*"; exit 1; }

cat <<'BANNER'

  ╔══════════════════════════════════════════════════════════╗
  ║  RASAD | رصد — Hostinger VPS Bootstrap                   ║
  ║  6-agent Arabic news verification platform               ║
  ╚══════════════════════════════════════════════════════════╝

BANNER

# ─── 1. Sanity checks ────────────────────────────────────────────
say "Checking environment…"

if [ "$(id -u)" -ne 0 ] && ! sudo -n true 2>/dev/null; then
    fail "Need root or passwordless sudo. Run as root or grant sudo."
fi

if ! command -v apt-get >/dev/null 2>&1; then
    fail "This script targets Ubuntu/Debian (apt-get not found)."
fi

# Check minimum RAM (warn if < 4GB)
TOTAL_RAM_MB=$(free -m | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM_MB" -lt 3500 ]; then
    warn "Detected ${TOTAL_RAM_MB}MB RAM. RASAD needs ≥ 4GB for AI models."
    warn "You can continue but expect OOM crashes when loading models."
    read -p "Continue anyway? [y/N] " -r
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi

ok "Ubuntu/Debian detected · ${TOTAL_RAM_MB}MB RAM"

# ─── 2. System update + base packages ────────────────────────────
say "Updating system + installing essentials…"
sudo apt-get update -qq
sudo apt-get install -y -qq curl git ca-certificates gnupg lsb-release ufw

ok "Base packages installed"

# ─── 3. Docker + Docker Compose plugin ───────────────────────────
if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    ok "Docker $(docker --version | awk '{print $3}' | tr -d ',') already present"
else
    say "Installing Docker (official)…"
    curl -fsSL https://get.docker.com | sudo sh -s -- --version 24.0 >/dev/null 2>&1 \
        || curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker "$USER"
    ok "Docker installed"
    warn "You may need to log out and back in for the docker group to take effect."
fi

# ─── 4. Clone repo ───────────────────────────────────────────────
if [ -d "$INSTALL_DIR/.git" ]; then
    say "Repo already cloned — pulling latest…"
    cd "$INSTALL_DIR" && git pull --ff-only
else
    say "Cloning $REPO_URL → $INSTALL_DIR"
    git clone "$REPO_URL" "$INSTALL_DIR"
fi
cd "$INSTALL_DIR"
ok "Repo at $INSTALL_DIR"

# ─── 5. Environment setup ────────────────────────────────────────
say "Setting up .env files…"

if [ ! -f backend/.env ]; then
    cp backend/.env.example backend/.env
    warn "Created backend/.env — YOU MUST fill in API keys before first verify"
fi

if [ ! -f .env ]; then
    cp .env.example .env
    ok ".env (frontend) ready"
fi

# Try to detect public IP for CORS hint
PUBLIC_IP=$(curl -fsSL https://api.ipify.org 2>/dev/null || echo "")
if [ -n "$PUBLIC_IP" ]; then
    ok "Public IP detected: $PUBLIC_IP"
fi

# ─── 6. Firewall ──────────────────────────────────────────────────
say "Opening firewall ports 22/80/443…"
sudo ufw allow OpenSSH >/dev/null 2>&1 || true
sudo ufw allow 80/tcp  >/dev/null 2>&1 || true
sudo ufw allow 443/tcp >/dev/null 2>&1 || true
sudo ufw --force enable >/dev/null 2>&1 || true
ok "Firewall configured"

# ─── 7. Build + start ─────────────────────────────────────────────
say "Building & starting containers (this takes 5–10 minutes the first time)…"
sg docker -c "cd '$INSTALL_DIR' && docker compose up -d --build" \
    || sudo docker compose up -d --build

sleep 4
say "Health check…"
for i in {1..30}; do
    if curl -fs http://localhost:8000/api/v1/health >/dev/null 2>&1; then
        ok "Backend is UP at http://localhost:8000"
        break
    fi
    [ $i -eq 30 ] && warn "Backend slow to start — check 'docker compose logs backend'"
    sleep 2
done

if curl -fs http://localhost:8080 >/dev/null 2>&1; then
    ok "Frontend is UP at http://localhost:8080"
fi

# ─── 8. Final instructions ───────────────────────────────────────
cat <<EOF

  ${GREEN}╔══════════════════════════════════════════════════════════╗${NC}
  ${GREEN}║  ✓ DEPLOYMENT COMPLETE                                   ║${NC}
  ${GREEN}╚══════════════════════════════════════════════════════════╝${NC}

  Local URLs (this VPS):
    • Frontend  →  http://localhost:8080
    • Backend   →  http://localhost:8000
    • OpenAPI   →  http://localhost:8000/docs
$([ -n "$PUBLIC_IP" ] && echo "
  Public URLs (test from anywhere):
    • Frontend  →  http://$PUBLIC_IP:8080
    • Backend   →  http://$PUBLIC_IP:8000")

  ─────────────────────────────────────────────────────────────
  ${YELLOW}⚠  REMAINING STEPS${NC}

  1. Add your API keys:
       nano $INSTALL_DIR/backend/.env
       # GEMINI_API_KEY (free: https://aistudio.google.com/apikey)
       # HF_API_TOKEN, TAVILY_API_KEY, SERPER_API_KEY (optional)

     Then restart:
       cd $INSTALL_DIR && docker compose restart backend

  2. (Optional) Domain + SSL:
       sudo apt install -y nginx certbot python3-certbot-nginx
       # Edit /etc/nginx/sites-available/rasad — see DEPLOY.md
       sudo certbot --nginx -d yourdomain.com

  3. Update CORS in backend/.env:
       CORS_ORIGINS=https://yourdomain.com

  ─────────────────────────────────────────────────────────────
  Useful commands:
    docker compose logs -f backend     follow backend logs
    docker compose ps                  list all running services
    docker compose restart backend     restart after .env change
    docker compose down                stop everything
    docker compose up -d --build       rebuild + restart

  Full guide: $INSTALL_DIR/DEPLOY.md
  Read the README: $INSTALL_DIR/README.md

EOF
