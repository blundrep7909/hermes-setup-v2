#!/usr/bin/env bash
set -euo pipefail

# Hermes Setup v2 -- Uninstall (local)
# Usage: bash scripts/uninstall.sh [-y]

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ─── Flag parsing ────────────────────────────────────────────────
YES_FLAG=false
for arg in "$@"; do
  case "$arg" in
    -y|--yes) YES_FLAG=true ;;
  esac
done

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo ""
echo -e "${BOLD}━━━ Hermes Setup v2 -- Uninstall ━━━${NC}"
echo ""
echo "This will remove:"
echo "  1. Docker container (hermes-aionui)"
echo "  2. Docker volume (hermes-data)"
echo "  3. Docker images"
echo "  4. Repo folder ($REPO_DIR)"
echo ""
echo -e "${RED}WARNING: This is destructive. All data will be lost.${NC}"
echo ""

if [ "$YES_FLAG" = false ]; then
  read -rp "Type 'yes' to confirm: " confirm
  if [ "$confirm" != "yes" ]; then
    info "Cancelled."
    exit 0
  fi
else
  info "Auto-confirmed (-y)"
fi

echo ""
echo -e "${BOLD}[1/4] Stopping and removing container...${NC}"
docker stop hermes-aionui 2>/dev/null && info "Container stopped" || warn "Not running"
docker rm hermes-aionui 2>/dev/null && info "Container removed" || warn "Not found"

echo ""
echo -e "${BOLD}[2/4] Removing Docker volume...${NC}"
docker volume rm hermes-data 2>/dev/null && info "Volume removed" || warn "Not found"

echo ""
echo -e "${BOLD}[3/4] Removing Docker images...${NC}"
for img in $(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i hermes); do
  docker rmi "$img" 2>/dev/null && info "Removed: $img" || true
done

echo ""
echo -e "${BOLD}[4/4] Removing repo folder...${NC}"
rm -rf "$REPO_DIR" && info "Removed: $REPO_DIR"

echo ""
echo -e "${GREEN}━━━ Uninstall Complete ━━━${NC}"
