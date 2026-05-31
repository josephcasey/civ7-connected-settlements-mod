#!/usr/bin/env bash
set -euo pipefail

# Shows recent Connected Settlements diagnostic lines from the Civ VII UI log.
# Pass -f to follow live.

LOG="${HOME}/Library/Application Support/Civilization VII/Logs/UI.log"

if [[ "${1:-}" == "-f" ]]; then
  tail -f "$LOG" | grep --line-buffered -i "cs-connections"
else
  grep -i "cs-connections" "$LOG" | tail -40
fi
