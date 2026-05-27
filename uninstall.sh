#!/usr/bin/env bash
set -euo pipefail

# Quick uninstall alias
# Usage: bash uninstall.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "$SCRIPT_DIR/install.sh" --uninstall
