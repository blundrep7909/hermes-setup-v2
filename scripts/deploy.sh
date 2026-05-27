#!/usr/bin/env bash
set -euo pipefail

# Deploy to VPS via SCP + SSH
# Usage: bash scripts/deploy.sh root@<vps-ip>
# Note: For GitHub-based deployment, use install.sh on the VPS directly.

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [ $# -lt 1 ]; then
  echo "Usage: bash scripts/deploy.sh root@<vps-ip>"
  exit 1
fi

SSH_TARGET="$1"
TAR_FILE="/tmp/hermes-aionui.tar"
REMOTE_DIR="~/hermes"

info "Building image..."
docker compose build

info "Exporting image to $TAR_FILE..."
docker save hermes-setup-v2-hermes-aionui:latest -o "$TAR_FILE"

info "Copying to $SSH_TARGET:$REMOTE_DIR ..."
ssh "$SSH_TARGET" "mkdir -p $REMOTE_DIR"
scp "$TAR_FILE" docker-compose.yml .env "$SSH_TARGET:$REMOTE_DIR/"

info "Loading and starting on VPS..."
ssh "$SSH_TARGET" "cd $REMOTE_DIR && docker load -i hermes-aionui.tar && docker compose up -d"

info "Done. Check: ssh $SSH_TARGET 'curl -s -o /dev/null -w %{http_code} http://localhost:3000/'"
