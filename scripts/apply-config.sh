#!/usr/bin/env bash
set -euo pipefail

# Apply optimized Hermes config to the running container
# Usage: bash scripts/apply-config.sh [--cost-optimized | --default]

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()   { echo -e "${GREEN}[config]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[config]${NC}  $*"; }
err()   { echo -e "${RED}[config]${NC}  $*"; }

CONTAINER="hermes-aionui"
CONFIG_FILE="/opt/data/config.yaml"
HERMES_CONFIG_DIR="/opt/data/.hermes"

if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  echo "Usage: bash scripts/apply-config.sh [PROFILE]"
  echo ""
  echo "Profiles:"
  echo "  --cost-optimized   Optimize for low cost (aggressive compression, cheap models)"
  echo "  --default          Reset to container defaults (managed by start.sh env vars)"
  echo ""
  echo "Examples:"
  echo "  bash scripts/apply-config.sh --cost-optimized"
  exit 0
fi

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^$CONTAINER$"; then
  err "Container '$CONTAINER' is not running."
  err "Start it first: docker compose up -d"
  exit 1
fi

case "${1:-}" in
  --cost-optimized)
    log "Applying cost-optimized config..."
    docker exec "$CONTAINER" hermes config set compression.threshold 0.3 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set compression.target_ratio 0.15 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set compression.protect_last_n 10 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set agent.reasoning_effort low 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set prompt_caching.cache_ttl 10m 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set delegation.max_iterations 20 2>/dev/null || true
    log "Cost-optimized config applied."
    ;;
  --default)
    log "Resetting to default config (managed by env vars)..."
    docker exec "$CONTAINER" hermes config set compression.threshold 0.5 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set compression.target_ratio 0.2 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set compression.protect_last_n 20 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set agent.reasoning_effort medium 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set prompt_caching.cache_ttl 5m 2>/dev/null || true
    docker exec "$CONTAINER" hermes config set delegation.max_iterations 50 2>/dev/null || true
    log "Default config applied."
    ;;
  *)
    err "Unknown profile: $1"
    echo "Usage: bash scripts/apply-config.sh --cost-optimized"
    exit 1
    ;;
esac

echo ""
log "Restart container to apply: docker compose restart $CONTAINER"
echo ""
