#!/usr/bin/env bash
set -euo pipefail

# Backup Hermes data volume
# Usage: bash scripts/backup.sh [output-dir]

RED='\033[0;31m'; GREEN='\033[0;32m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

BACKUP_DIR="${1:-$HOME/hermes-backups}"
mkdir -p "$BACKUP_DIR"
BACKUP_FILE="$BACKUP_DIR/hermes-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
VOLUME="hermes-setup-v2_hermes-data"

info "Backing up volume $VOLUME to $BACKUP_FILE ..."
docker run --rm -v "${VOLUME}:/data" -v "${BACKUP_DIR}:/backup" alpine tar czf "/backup/$(basename "$BACKUP_FILE")" -C /data .

echo ""
echo -e "${GREEN}Backup saved:${NC} $BACKUP_FILE"
echo ""
echo "Restore with:"
echo "  docker run --rm -v ${VOLUME}:/data -v ${BACKUP_DIR}:/backup alpine tar xzf \"/backup/$(basename "$BACKUP_FILE")\" -C /data"
echo ""
