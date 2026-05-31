#!/usr/bin/env bash
set -euo pipefail

# Fast test cycle for the Connected Settlements mod:
#   1. quit Civ VII
#   2. sync the latest mod files into the local Mods directory
#   3. clear Mods.sqlite (the mod cache) so Civ re-reads the modinfo + scripts
#
# By default it stops there so you can relaunch the game manually. Pass --launch
# to have the script reopen Civ VII for you.
#
# Civ VII caches the per-mod UIScript list in Mods.sqlite. Without clearing it,
# changes to which scripts a modinfo loads are NOT reliably picked up on a plain
# restart — the game keeps serving the previously cached script set.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
APP_SUPPORT="${HOME}/Library/Application Support/Civilization VII"
CACHE_FILE="${APP_SUPPORT}/Mods.sqlite"
CIV7_APP="${HOME}/Library/Application Support/Steam/steamapps/common/Sid Meier's Civilization VII/CivilizationVII.app"

echo "=== Connected Settlements — retest ==="

echo "1. Quitting Civ VII..."
if pgrep -f "Civilization.*VII" >/dev/null 2>&1; then
    pkill -9 -f "Civilization.*VII" 2>/dev/null || killall -9 "CivilizationVII" 2>/dev/null || true
    for _ in {1..10}; do
        pgrep -f "Civilization.*VII" >/dev/null 2>&1 || break
        sleep 1
    done
    sleep 1
else
    echo "   (not running)"
fi

echo "2. Syncing mod files..."
bash "${ROOT_DIR}/scripts/install_local.sh" | sed 's/^/   /'

echo "3. Clearing mod cache..."
if [[ -f "$CACHE_FILE" ]]; then
    rm -f "$CACHE_FILE" && echo "   removed Mods.sqlite"
else
    echo "   (no Mods.sqlite present)"
fi

if [[ "${1:-}" != "--launch" ]]; then
    echo "Done. Cache cleared — relaunch Civ VII manually, then read logs with: scripts/tail_log.sh"
    exit 0
fi

echo "4. Launching Civ VII..."
if [[ ! -d "$CIV7_APP" ]]; then
    echo "   Civ VII not found at: $CIV7_APP" >&2
    exit 1
fi
sleep 1
open "$CIV7_APP"
echo "Done. After it loads, read logs with: scripts/tail_log.sh"
