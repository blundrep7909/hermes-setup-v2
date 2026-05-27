#!/usr/bin/env bash
set -euo pipefail

# Install evey/hermes plugins into the running container
# Usage: bash scripts/install-plugins.sh [--all | --core | --list]
#        bash scripts/install-plugins.sh --core,memory

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log()   { echo -e "${GREEN}[plugins]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[plugins]${NC}  $*"; }
err()   { echo -e "${RED}[plugins]${NC}  $*"; }

REPO_URL="https://github.com/42-evey/hermes-plugins.git"
CONTAINER="hermes-aionui"
PLUGIN_DIR="/opt/data/plugins"
CACHE="/tmp/evey-plugin-cache"

# Category -> plugin list (space-separated)
# The order matters: install utils before anything else
all_core="evey-bridge evey-goals evey-delegate-model evey-status evey-cost-guard"
all_observability="evey-telemetry evey-watchdog evey-mqtt"
all_social="evey-moltbook evey-proactive evey-news"
all_memory="evey-memory-adaptive evey-memory-consolidate evey-learner evey-habits"
all_quality="evey-reflect evey-validate evey-council evey-email-guard"
all_extra="evey-autonomy evey-research evey-scheduler evey-digest evey-delegation-score evey-identity evey-session-guard evey-sandbox evey-cache"

show_list() {
  echo ""
  echo -e "${BOLD}Available plugin categories:${NC}"
  echo -e "  ${CYAN}core${NC}           $all_core"
  echo -e "  ${CYAN}observability${NC}  $all_observability"
  echo -e "  ${CYAN}social${NC}         $all_social"
  echo -e "  ${CYAN}memory${NC}         $all_memory"
  echo -e "  ${CYAN}quality${NC}        $all_quality"
  echo -e "  ${CYAN}extra${NC}          $all_extra"
  echo ""
}

# Parse args
if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash scripts/install-plugins.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --all       Install all plugins"
  echo "  --list      Show available plugin categories"
  echo "  --core      Install core plugins (recommended)"
  echo "  CATEGORIES  Comma-separated, e.g. --core,memory"
  echo ""
  echo "Examples:"
  echo "  bash scripts/install-plugins.sh --core"
  echo "  bash scripts/install-plugins.sh --core,memory,quality"
  echo "  bash scripts/install-plugins.sh --all"
  exit 0
fi

if [ "$1" = "--list" ]; then
  show_list
  exit 0
fi

# Build plugin list from category argument
arg="${1#--}"
plugins=""
case "$arg" in
  all) plugins="$all_core $all_observability $all_social $all_memory $all_quality $all_extra" ;;
  core|observability|social|memory|quality|extra)
    eval "plugins=\"\$all_$arg\"" ;;
  *)
    IFS=',' read -ra cats <<< "$arg"
    for c in "${cats[@]}"; do
      c="$(echo "$c" | tr -d ' ')"
      case "$c" in
        core|observability|social|memory|quality|extra)
          eval "added=\"\$all_$c\""
          plugins="$plugins $added" ;;
        *) warn "Unknown category: $c (skipping)" ;;
      esac
    done
    ;;
esac

# Deduplicate (simple: use the "all categories" string which has no duplicates)
unique=""
for p in $plugins; do
  case " $unique " in *" $p "*) ;; *) unique="$unique $p" ;; esac
done
plugins="${unique# }"

if [ -z "$plugins" ]; then
  err "No valid categories selected."
  exit 1
fi

# Check container
if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$CONTAINER$"; then
  err "Container '$CONTAINER' is not running."
  err "Start it first: docker compose up -d"
  exit 1
fi

# Clone/update plugin repo
if [ -d "$CACHE" ] && [ -d "$CACHE/.git" ]; then
  log "Updating plugin cache..."
  git -C "$CACHE" pull --quiet 2>/dev/null || { rm -rf "$CACHE"; git clone --depth 1 "$REPO_URL" "$CACHE"; }
else
  log "Cloning plugin repository..."
  rm -rf "$CACHE"
  git clone --depth 1 "$REPO_URL" "$CACHE"
fi

# Create plugins dir
docker exec "$CONTAINER" mkdir -p "$PLUGIN_DIR"

# Install shared utils
if [ -f "$CACHE/evey_utils.py" ]; then
  docker cp "$CACHE/evey_utils.py" "${CONTAINER}:${PLUGIN_DIR}/evey_utils.py"
  log "Installed evey_utils.py"
fi

# Install each plugin
installed=0
for plugin in $plugins; do
  src="$CACHE/$plugin"
  if [ ! -d "$src" ]; then
    warn "Plugin $plugin not found, skipping"
    continue
  fi
  docker exec "$CONTAINER" rm -rf "${PLUGIN_DIR:?}/$plugin" 2>/dev/null || true
  if docker cp "$src" "${CONTAINER}:${PLUGIN_DIR}/$plugin" 2>/dev/null; then
    log "Installed $plugin"
    installed=$((installed + 1))
  else
    warn "Failed to copy $plugin"
  fi
done

# Fix ownership
docker exec "$CONTAINER" chown -R hermes:hermes "$PLUGIN_DIR" 2>/dev/null || true

echo ""
log "Installed $installed plugins."
echo ""
echo -e "${YELLOW}Restart to load plugins:${NC}"
echo "  docker compose restart $CONTAINER"
echo ""
