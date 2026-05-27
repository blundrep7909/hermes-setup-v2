#!/usr/bin/env bash
set -euo pipefail

# Hermes + AionUI — One-command setup
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/blundrep7909/hermes-setup-v2/main/install.sh | bash
#   curl -fsSL ... | bash -s -- --update
#   curl -fsSL ... | bash -s -- --uninstall
#   curl -fsSL ... | bash -s -- --backup
#   curl -fsSL ... | bash -s -- --plugins=core    (evey plugins)
#   curl -fsSL ... | bash -s -- --skills=dev,ops  (Terp skills)
#   curl -fsSL ... | bash -s -- --config=cost-optimized

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

REPO_URL="https://github.com/blundrep7909/hermes-setup-v2.git"
IMAGE="ghcr.io/blundrep7909/hermes-setup-v2:latest"
CONTAINER="hermes-aionui"
VOLUME="hermes-setup-v2_hermes-data"
COMPOSE_FILE="docker-compose.yml"

# ─── Flags ───────────────────────────────────────────────────────
DO_UNINSTALL=false
DO_UPDATE=false
DO_BACKUP=false
DO_PLUGINS=false
DO_SKILLS=false
DO_CONFIG=false
PLUGIN_CATEGORIES=""
SKILL_CATEGORIES=""
CONFIG_PROFILE=""

for arg in "$@"; do
  case "$arg" in
    --uninstall|-y|--yes) DO_UNINSTALL=true ;;
    --update|-u)          DO_UPDATE=true ;;
    --plugins=*)          DO_PLUGINS=true; PLUGIN_CATEGORIES="${arg#*=}" ;;
    --plugins|-p)         DO_PLUGINS=true; PLUGIN_CATEGORIES="core" ;;
    --skills=*)           DO_SKILLS=true; SKILL_CATEGORIES="${arg#*=}" ;;
    --skills|-s)          DO_SKILLS=true; SKILL_CATEGORIES="dev,ops" ;;
    --config=*)           DO_CONFIG=true; CONFIG_PROFILE="${arg#*=}" ;;
    --config|-c)          DO_CONFIG=true; CONFIG_PROFILE="cost-optimized" ;;
    --backup|-b)          DO_BACKUP=true ;;
  esac
done

# ─── Uninstall ───────────────────────────────────────────────────
if $DO_UNINSTALL; then
  echo ""
  echo -e "${BOLD}━━━ Uninstalling Hermes + AionUI ━━━${NC}"
  echo ""

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$CONTAINER$"; then
    info "Stopping container..."
    docker compose down -v 2>/dev/null || docker stop "$CONTAINER" && docker rm "$CONTAINER"
  fi

  if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${VOLUME}$"; then
    info "Removing volume..."
    docker volume rm "$VOLUME" 2>/dev/null || true
  fi

  if docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null | grep -q "^ghcr.io/blundrep7909/hermes-setup-v2"; then
    info "Removing image..."
    docker rmi "$IMAGE" 2>/dev/null || true
  fi

  info "Removing files..."
  rm -rf "$HOME/hermes-setup-v2" 2>/dev/null || true

  echo ""
  echo -e "${GREEN}Uninstall complete.${NC}"
  exit 0
fi

# ─── Update ──────────────────────────────────────────────────────
if $DO_UPDATE; then
  echo ""
  echo -e "${BOLD}━━━ Updating Hermes + AionUI ─────────────────────────────${NC}"
  echo ""
  info "Pulling latest image..."
  docker compose pull 2>/dev/null || docker pull "$IMAGE"
  info "Recreating container..."
  docker compose up -d 2>/dev/null || docker stop "$CONTAINER" 2>/dev/null; docker rm "$CONTAINER" 2>/dev/null; docker compose up -d
  echo ""
  echo -e "${GREEN}Update complete.${NC}"
  exit 0
fi

# ─── Backup ──────────────────────────────────────────────────────
if $DO_BACKUP; then
  echo ""
  echo -e "${BOLD}━━━ Backing up Hermes data ──────────────────────────────${NC}"
  echo ""

  BACKUP_DIR="${BACKUP_DIR:-$HOME/hermes-backups}"
  mkdir -p "$BACKUP_DIR"
  BACKUP_FILE="$BACKUP_DIR/hermes-backup-$(date +%Y%m%d_%H%M%S).tar.gz"

  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$CONTAINER$"; then
    VOLUME_NAME=$(docker inspect "$CONTAINER" --format '{{range .Mounts}}{{.Name}}{{end}}' 2>/dev/null)
    if [ -n "$VOLUME_NAME" ]; then
      info "Backing up volume $VOLUME_NAME to $BACKUP_FILE"
      docker run --rm -v "${VOLUME_NAME}:/data" -v "${BACKUP_DIR}:/backup" alpine tar czf "/backup/$(basename "$BACKUP_FILE")" -C /data . 2>&1
      echo -e "${GREEN}Backup saved: $BACKUP_FILE${NC}"
    else
      error "Could not detect volume name."
      exit 1
    fi
  else
    info "Container not running. Backing up volume directly..."
    if docker volume ls --format '{{.Name}}' 2>/dev/null | grep -q "^${VOLUME}$"; then
      docker run --rm -v "${VOLUME}:/data" -v "${BACKUP_DIR}:/backup" alpine tar czf "/backup/$(basename "$BACKUP_FILE")" -C /data .
      echo -e "${GREEN}Backup saved: $BACKUP_FILE${NC}"
    else
      error "No data volume found. Nothing to back up."
      exit 1
    fi
  fi
  exit 0
fi

# ─── Plugins (standalone) ─────────────────────────────────────────
if $DO_PLUGINS; then
  echo ""
  echo -e "${BOLD}━━━ Installing Plugins ───────────────────────────────────${NC}"
  echo ""
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || echo "$PWD")"
  if [ -f "$SCRIPT_DIR/scripts/install-plugins.sh" ]; then
    bash "$SCRIPT_DIR/scripts/install-plugins.sh" "--${PLUGIN_CATEGORIES}"
    info "Restarting container to load plugins..."
    docker compose restart "$CONTAINER" 2>/dev/null || docker restart "$CONTAINER"
  else
    warn "install-plugins.sh not found. Run from the repo directory."
  fi
  exit 0
fi

# ─── Skills (standalone) ──────────────────────────────────────────
if $DO_SKILLS; then
  echo ""
  echo -e "${BOLD}━━━ Installing Terp Skills ─────────────────────────────────${NC}"
  echo ""
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || echo "$PWD")"
  if [ -f "$SCRIPT_DIR/scripts/install-skills.sh" ]; then
    bash "$SCRIPT_DIR/scripts/install-skills.sh" "--${SKILL_CATEGORIES}"
  else
    warn "install-skills.sh not found."
  fi
  exit 0
fi

# ─── Config (standalone) ──────────────────────────────────────────
if $DO_CONFIG; then
  echo ""
  echo -e "${BOLD}━━━ Applying ${CONFIG_PROFILE} Config ────────────────────────${NC}"
  echo ""
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || echo "$PWD")"
  if [ -f "$SCRIPT_DIR/scripts/apply-config.sh" ]; then
    bash "$SCRIPT_DIR/scripts/apply-config.sh" "--${CONFIG_PROFILE}"
  else
    warn "apply-config.sh not found."
  fi
  exit 0
fi

# ─── Install ─────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━ Hermes + AionUI — Install ━━━${NC}"
echo ""

# 1. Check Docker
if ! command -v docker &>/dev/null; then
  echo ""
  warn "Docker not found. Install it first:"
  echo "  curl -fsSL https://get.docker.com | sh"
  echo "  sudo usermod -aG docker \$USER"
  echo "  (log out and back in, then re-run this script)"
  echo ""
  exit 1
fi
info "Docker: $(docker --version 2>/dev/null | head -1)"

# 2. Check docker compose plugin
if ! docker compose version &>/dev/null; then
  error "docker compose plugin not found. Install it:"
  error "  sudo apt install docker-compose-plugin"
  exit 1
fi

# 3. Ensure we're in the repo dir
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd 2>/dev/null || echo "$PWD")"
cd "$SCRIPT_DIR"

# 4. Create .env if missing
if [ ! -f .env ]; then
  if [ -f .env.example ]; then
    cp .env.example .env
    echo ""
    echo -e "${YELLOW}  ┌─────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}  │  .env file created from .env.example        │${NC}"
    echo -e "${YELLOW}  │  Edit it with: nano .env                    │${NC}"
    echo -e "${YELLOW}  │  Then run the script again.                 │${NC}"
    echo -e "${YELLOW}  └─────────────────────────────────────────────┘${NC}"
    echo ""
    exit 0
  fi
fi

# 5. Check OPENROUTER_API_KEY
if grep -q "OPENROUTER_API_KEY=$" .env 2>/dev/null || ! grep -q "OPENROUTER_API_KEY=" .env 2>/dev/null; then
  echo ""
  echo -e "${YELLOW}  ┌─────────────────────────────────────────────┐${NC}"
  echo -e "${YELLOW}  │  OPENROUTER_API_KEY not set in .env         │${NC}"
  echo -e "${YELLOW}  │  Edit it with: nano .env                    │${NC}"
  echo -e "${YELLOW}  │  Then run the script again.                 │${NC}"
  echo -e "${YELLOW}  └─────────────────────────────────────────────┘${NC}"
  echo ""
  exit 1
fi

# 6. Pull image
echo ""
info "Pulling image from ghcr.io..."
docker compose pull 2>&1 || docker pull "$IMAGE"

# 7. Start container
echo ""
info "Starting container..."
docker compose up -d

# 8. Wait for ready
echo ""
info "Waiting for container to be ready..."
for i in $(seq 1 12); do
  sleep 5
  if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$CONTAINER$"; then
    STATUS=$(docker inspect "$CONTAINER" --format '{{.State.Status}}' 2>/dev/null || echo "running")
    info "Container status: $STATUS"
    break
  fi
  info "Waiting... ($i/12)"
done

# 9. Reset admin password
echo ""
info "Generating admin password..."
ADMIN_PASS=$(docker exec "$CONTAINER" /opt/aionui/aionui-web resetpass --data-dir /opt/data 2>/dev/null | grep -oP 'new password: \K.*' || echo "")
if [ -z "$ADMIN_PASS" ]; then
  warn "Could not generate password. Run later:"
  echo "  docker exec $CONTAINER /opt/aionui/aionui-web resetpass --data-dir /opt/data"
fi

# 10. Install plugins (if requested)
if $DO_PLUGINS; then
  echo ""
  info "Installing plugins (${PLUGIN_CATEGORIES})..."
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  if [ -f "$SCRIPT_DIR/scripts/install-plugins.sh" ]; then
    bash "$SCRIPT_DIR/scripts/install-plugins.sh" "--${PLUGIN_CATEGORIES}" || warn "Plugin install had issues"
    info "Restarting container to load plugins..."
    docker compose restart "$CONTAINER"
  else
    warn "install-plugins.sh not found, skipping plugins"
  fi
fi

# 11. Done
echo ""
echo -e "${GREEN}━━━ Install Complete ━━━${NC}"
echo ""
echo "  URL:          http://localhost:3000"
echo "  Username:     admin"
echo "  Password:     $ADMIN_PASS"
echo ""
echo "  After login, select 'Hermes' agent in the UI."
echo ""
echo -e "${YELLOW}Commands:${NC}"
echo "  Update:       bash install.sh --update"
echo "  Plugins:      bash install.sh --plugins           (evey core plugins)"
echo "  Plugins:      bash install.sh --plugins=all       (all evey plugins)"
echo "  Skills:       bash install.sh --skills            (Terp dev+ops skills)"
echo "  Skills:       bash install.sh --skills=all        (all Terp skills)"
echo "  Config:       bash install.sh --config=cost-optimized"
echo "  Backup:       bash install.sh --backup"
echo "  Uninstall:    bash install.sh --uninstall"
echo ""
