#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

echo ""
echo -e "${BOLD}━━━ Hermes + AionUI Host Uninstall ━━━${NC}"
echo ""
echo "This will remove ALL Hermes Agent and AionUI installations from this machine."
echo "  - Hermes CLI + config + venv + data"
echo "  - AionUI WebUI binary + data"
echo "  - Systemd services (user-level)"
echo "  - Cron jobs, skills, logs, memories"
echo ""
echo -e "${RED}WARNING: This is destructive. Config, chat history, and API keys will be lost.${NC}"
echo ""

read -rp "Type 'yes' to confirm: " confirm
if [ "$confirm" != "yes" ]; then
  info "Cancelled."
  exit 0
fi

# ─── 1. Stop services ──────────────────────────────────────────────
echo ""
echo -e "${BOLD}[1/6] Stopping services...${NC}"

# systemd user services
for svc in hermes-gateway aionui-webui hermes-dashboard; do
  if systemctl --user list-units --quiet 2>/dev/null; then
    systemctl --user disable --now "$svc" 2>/dev/null && info "Disabled: $svc" || true
  fi
done

# Kill any running processes
pkill -f "hermes\s+gateway" 2>/dev/null && info "Killed hermes gateway" || true
pkill -f "aionui-web" 2>/dev/null && info "Killed aionui-web" || true
pkill -f "hermes\s+acp" 2>/dev/null && info "Killed hermes acp" || true

# ─── 2. Remove systemd files ──────────────────────────────────────
echo ""
echo -e "${BOLD}[2/6] Removing systemd service files...${NC}"

for unit in hermes-gateway aionui-webui; do
  for dir in "$HOME/.config/systemd/user" "/etc/systemd/system"; do
    f="$dir/$unit.service"
    if [ -f "$f" ]; then
      rm -f "$f" && info "Removed: $f" || warn "Could not remove: $f"
    fi
  done
done

# Reload systemd
systemctl --user daemon-reload 2>/dev/null || true

# ─── 3. Remove Hermes ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}[3/6] Removing Hermes Agent...${NC}"

# Find Hermes installation
HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
HERMES_VENV="${HERMES_VENV:-$HOME/.hermes-venv}"
HERMES_LOC=$(pip show hermes-agent 2>/dev/null | grep Location | awk '{print $2}' || echo "")

# Remove hermnes home directory
if [ -d "$HERMES_HOME" ]; then
  rm -rf "$HERMES_HOME" && info "Removed: $HERMES_HOME" || warn "Could not remove $HERMES_HOME"
fi

# Remove venv
if [ -d "$HERMES_VENV" ]; then
  rm -rf "$HERMES_VENV" && info "Removed: $HERMES_VENV" || warn "Could not remove $HERMES_VENV"
fi

# Remove Hermes config in XDG locations
for dir in "$HOME/.config/hermes" "$HOME/.local/share/hermes"; do
  if [ -d "$dir" ]; then
    rm -rf "$dir" && info "Removed: $dir" || true
  fi
done

# Remove Hermes Python package
if command -v pip &>/dev/null; then
  pip uninstall -y hermes-agent 2>/dev/null && info "Uninstalled Python package: hermes-agent" || true
fi
if command -v pip3 &>/dev/null; then
  pip3 uninstall -y hermes-agent 2>/dev/null && info "Uninstalled Python package: hermes-agent (pip3)" || true
fi

# Remove optional system install
for d in /opt/hermes /usr/local/hermes; do
  if [ -d "$d" ]; then
    rm -rf "$d" && info "Removed: $d" || warn "Could not remove $d (try sudo)"
  fi
done

# ─── 4. Remove AionUI ─────────────────────────────────────────────
echo ""
echo -e "${BOLD}[4/6] Removing AionUI WebUI...${NC}"

# Find AionUI binary
for d in /opt/aionui /opt/aionui-web "$HOME/aionui-web" "$HOME/hermes-aionui"; do
  if [ -d "$d" ]; then
    rm -rf "$d" && info "Removed: $d" || warn "Could not remove $d (try sudo)"
  fi
done

# Remove AionUI data
for d in /opt/data/.aionui-web "$HOME/.aionui-web"; do
  if [ -d "$d" ]; then
    rm -rf "$d" && info "Removed: $d" || true
  fi
done

# ─── 5. Remove shared data ───────────────────────────────────────
echo ""
echo -e "${BOLD}[5/6] Removing shared data...${NC}"

# Hermes data dir (config, logs, memory, skills)
for d in /opt/data "$HOME/hermes-data"; do
  if [ -d "$d" ]; then
    # Only remove if it looks like a Hermes/AionUI data dir
    if [ -f "$d/config.yaml" ] || [ -f "$d/.hermes/config.yaml" ] || [ -f "$d/aionui-backend.db" ]; then
      rm -rf "$d" && info "Removed data dir: $d" || warn "Could not remove $d"
    fi
  fi
done

# Remove cron jobs
crontab -l 2>/dev/null | grep -v hermes | grep -v aionui | crontab - 2>/dev/null || true
info "Cleaned Hermes-related cron jobs"

# Remove env files
rm -f "$HOME/.hermes-setup/state" 2>/dev/null || true
rm -f "$HOME/.hermes-setup/api_key" 2>/dev/null || true
rm -rf "$HOME/.hermes-setup/pids" 2>/dev/null || true

# Remove shell integration
for rc in .bashrc .zshrc .config/fish/config.fish; do
  f="$HOME/$rc"
  if [ -f "$f" ]; then
    sed -i '/hermes/d' "$f" 2>/dev/null || true
  fi
done

# ─── 6. Remove Docker resources (if used) ─────────────────────────
echo ""
echo -e "${BOLD}[6/6] Cleaning Docker resources (if any)...${NC}"

if command -v docker &>/dev/null; then
  docker stop hermes-aionui 2>/dev/null && info "Stopped Docker container" || true
  docker rm hermes-aionui 2>/dev/null && info "Removed Docker container" || true
  docker volume rm hermes-data 2>/dev/null && info "Removed Docker volume" || true
  for img in $(docker images --format '{{.Repository}}:{{.Tag}}' | grep -i hermes 2>/dev/null); do
    docker rmi "$img" 2>/dev/null || true
  done
fi

# ─── Done ─────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}━━━ Uninstall Complete ━━━${NC}"
echo ""
echo "Remaining Hermes/AionUI files (if any):"
find "$HOME" /opt /usr/local -maxdepth 4 -name "*hermes*" -o -name "*aionui*" -o -name "*aion*" 2>/dev/null | grep -v cache | grep -v ".git" | head -10 || echo "  (none found)"
echo ""
echo "If you used sudo for installation, some files may remain in /opt."
echo "Check: sudo find /opt -name '*hermes*' -o -name '*aionui*' 2>/dev/null"
