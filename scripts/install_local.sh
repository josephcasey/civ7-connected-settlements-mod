#!/usr/bin/env bash
set -euo pipefail

# Syncs the mod's runtime files into the local Civ VII Mods directory so the
# game loads the latest code on next launch. UI-only files, so no build step.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
MODS_DIR="${HOME}/Library/Application Support/Civilization VII/Mods/connected-settlements"

rsync -av \
  --include="connected-settlements.modinfo" \
  --include="ui/" --include="ui/**" \
  --include="text/" --include="text/**" \
  --exclude="*" \
  "${ROOT_DIR}/" \
  "${MODS_DIR}/"

echo "Installed to: ${MODS_DIR}"
