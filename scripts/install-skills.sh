#!/usr/bin/env bash
set -euo pipefail

# Install Terp optimization skills into the running container
# Usage: bash scripts/install-skills.sh [--all | --dev | --ops | --security]

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${GREEN}[skills]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[skills]${NC}  $*"; }
err()   { echo -e "${RED}[skills]${NC}  $*"; }

REPO_URL="https://github.com/OnlyTerp/hermes-optimization-guide.git"
CONTAINER="hermes-aionui"
SKILLS_DIR="/opt/data/skills"
CACHE="/tmp/terp-skills-cache"

all_dev="meeting-prep pr-review release-notes"
all_ops="cost-report daily-inbox-triage hermes-weekly nightly-backup telegram-triage weekly-dep-audit"
all_security="audit-approval-bypass audit-mcp rotate-secrets spam-trap"

show_list() {
  echo ""
  echo -e "${BOLD}Available skill categories:${NC}"
  echo -e "  ${CYAN}dev${NC}       $all_dev"
  echo -e "  ${CYAN}ops${NC}       $all_ops"
  echo -e "  ${CYAN}security${NC}  $all_security"
  echo ""
}

if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash scripts/install-skills.sh [OPTIONS]"
  echo "  --all          Install all skills"
  echo "  --list         Show available skill categories"
  echo "  --dev          Install dev skills"
  echo "  --ops          Install ops skills"
  echo "  --security     Install security skills"
  echo "  --dev,ops      Comma-separated categories"
  exit 0
fi

if [ "$1" = "--list" ]; then
  show_list; exit 0
fi

arg="${1#--}"
skills=""
case "$arg" in
  all) skills="$all_dev $all_ops $all_security" ;;
  dev|ops|security) eval "skills=\"\$all_$arg\"" ;;
  *)
    IFS=',' read -ra cats <<< "$arg"
    for c in "${cats[@]}"; do
      c="$(echo "$c" | tr -d ' ')"
      case "$c" in
        dev|ops|security) eval "added=\"\$all_$c\""; skills="$skills $added" ;;
        *) warn "Unknown category: $c (skipping)" ;;
      esac
    done
    ;;
esac

skills="$(echo "$skills" | tr ' ' '\n' | awk '!seen[$0]++' | tr '\n' ' ' | sed 's/ $//')"

if [ -z "$skills" ]; then
  err "No valid categories selected."; exit 1
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$CONTAINER$"; then
  err "Container '$CONTAINER' is not running."
  err "Start it first: docker compose up -d"
  exit 1
fi

# Clone the Terp repo
if [ -d "$CACHE" ] && [ -d "$CACHE/.git" ]; then
  log "Updating skills cache..."
  git -C "$CACHE" pull --quiet 2>/dev/null || { rm -rf "$CACHE"; git clone --depth 1 "$REPO_URL" "$CACHE"; }
else
  log "Cloning Terp skills repository..."
  rm -rf "$CACHE"
  git clone --depth 1 "$REPO_URL" "$CACHE"
fi

# Create category dirs in skills directory
for cat in dev ops security; do
  docker exec "$CONTAINER" mkdir -p "${SKILLS_DIR}/${cat}"
done

installed=0
for skill in $skills; do
  case "$skill" in
    meeting-prep|pr-review|release-notes)     cat="dev" ;;
    cost-report|daily-inbox-triage|hermes-weekly|nightly-backup|telegram-triage|weekly-dep-audit) cat="ops" ;;
    audit-approval-bypass|audit-mcp|rotate-secrets|spam-trap) cat="security" ;;
  esac
  src="$CACHE/skills/${cat}/${skill}"
  if [ ! -d "$src" ]; then
    warn "Skill $skill not found at $src, skipping"
    continue
  fi
  docker exec "$CONTAINER" rm -rf "${SKILLS_DIR:?}/${cat}/${skill}" 2>/dev/null || true
  if docker cp "$src" "${CONTAINER}:${SKILLS_DIR}/${cat}/${skill}" 2>/dev/null; then
    log "Installed ${cat}/${skill}"
    installed=$((installed + 1))
  else
    warn "Failed to copy $skill"
  fi
done

docker exec "$CONTAINER" chown -R hermes:hermes "$SKILLS_DIR" 2>/dev/null || true

echo ""
log "Installed $installed skills."
echo ""
echo -e "${YELLOW}The new skills are auto-discovered by Hermes — no restart needed.${NC}"
echo ""
