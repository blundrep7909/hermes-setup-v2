#!/usr/bin/env bash
set -euo pipefail

# Install RTK binary + rtk-hermes plugin into the running container
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log()  { echo -e "${GREEN}[rtk]${NC}  $*"; }
warn() { echo -e "${YELLOW}[rtk]${NC}  $*"; }
err()  { echo -e "${RED}[rtk]${NC}  $*"; }

CONTAINER="hermes-aionui"
HERMES_PY="/opt/hermes/.venv/bin/python"

if ! docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${CONTAINER}$"; then
  err "Container '$CONTAINER' not running."; exit 1
fi

log "Installing RTK binary..."
docker exec -w /tmp "$CONTAINER" bash -c "$(cat <<'PYTHON'
python3 <<'PYINNER'
import urllib.request, tarfile, os
url = "https://github.com/rtk-ai/rtk/releases/download/v0.42.0/rtk-x86_64-unknown-linux-musl.tar.gz"
urllib.request.urlretrieve(url, "/tmp/rtk.tar.gz")
tarfile.open("/tmp/rtk.tar.gz").extract("rtk", "/usr/local/bin/")
os.chmod("/usr/local/bin/rtk", 0o755)
print("RTK", os.popen("rtk --version").read().strip())
PYINNER
PYTHUN
)"

log "Installing rtk-hermes plugin..."
docker exec "$CONTAINER" $HERMES_PY -m pip install -q rtk-hermes 2>&1 || {
  warn "pip install failed, trying uv..."
  docker exec "$CONTAINER" bash -c "pip install rtk-hermes" 2>&1
}

log "Enabling plugin in Hermes config..."
docker exec "$CONTAINER" bash -c '
  CFG="/opt/data/config.yaml"
  if grep -q "plugins:" "$CFG" 2>/dev/null; then
    if grep -q "rtk-rewrite" "$CFG" 2>/dev/null; then
      echo "rtk-rewrite already enabled"
    else
      sed -i "/enabled:/a\    - rtk-rewrite" "$CFG"
    fi
  else
    cat >> "$CFG" <<"EOF"

plugins:
  enabled:
    - rtk-rewrite
EOF
  fi
'

log "Verification..."
docker exec "$CONTAINER" $HERMES_PY -c "
import importlib.metadata as md
for ep in md.entry_points().select(group='hermes_agent.plugins'):
    if ep.name == 'rtk-rewrite':
        module = ep.load()
        print(f'  Plugin OK: {ep.name} {ep.dist.metadata[\"Version\"]}')
"

log "Done. Restart container: docker compose restart $CONTAINER"
