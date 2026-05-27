#!/usr/bin/env bash
set -euo pipefail

# Build and push the Docker image to ghcr.io
# Requires: GitHub PAT with write:packages scope
# Usage: GITHUB_TOKEN=ghp_xxx bash scripts/build-and-push.sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

IMAGE="ghcr.io/blundrep7909/hermes-setup-v2:latest"
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SCRIPT_DIR"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  error "GITHUB_TOKEN not set."
  echo "  Usage: GITHUB_TOKEN=ghp_xxx bash scripts/build-and-push.sh"
  exit 1
fi

info "Logging in to ghcr.io..."
echo "$GITHUB_TOKEN" | docker login ghcr.io -u blundrep7909 --password-stdin

info "Fetching latest AionUI version from GitHub API..."
AIONUI_VERSION=$(curl -fsSL https://api.github.com/repos/iOfficeAI/AionUi/releases/latest 2>/dev/null | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/' || echo "")
if [ -z "$AIONUI_VERSION" ]; then
  warn "Could not detect latest AionUI version, falling back to 2.1.4"
  AIONUI_VERSION="2.1.4"
fi
info "Building image (Hermes: latest from Docker Hub, AionUI: v$AIONUI_VERSION)..."
docker build --build-arg AIONUI_VERSION="$AIONUI_VERSION" -t "$IMAGE" .

info "Pushing to ghcr.io..."
docker push "$IMAGE"

info "Done. Image pushed: $IMAGE"
