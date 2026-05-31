#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
LOCAL_MODINFO_FILE="${ROOT_DIR}/connected-settlements.modinfo"
WORKSHOP_MODINFO_FILE="${ROOT_DIR}/upload/steam/connected-settlements.workshop.modinfo"
WORKSHOP_MOD_TEXT_FILE="${ROOT_DIR}/upload/steam/ModInfoText.workshop.xml"
WORKSHOP_INGAME_TEXT_FILE="${ROOT_DIR}/upload/steam/InGameText.workshop.xml"
CONFIG_FILE="${ROOT_DIR}/upload/steam/workshop.conf"
PREVIEW_FILE="${ROOT_DIR}/upload/steam/preview.png"
OUTPUT_DIR="${ROOT_DIR}/build/steam"
STAGING_DIR="${OUTPUT_DIR}/content"
STAGED_MOD_DIR="${STAGING_DIR}/connected-settlements"
OUTPUT_VDF="${OUTPUT_DIR}/workshop_build_item.vdf"
KEYCHAIN_SERVICE="${STEAM_KEYCHAIN_SERVICE:-civ7-steamcmd-upload}"

APP_ID=1295660
PUBLISHEDFILEID=0
VISIBILITY=2
CHANGE_NOTE="v0.1.0: initial Workshop release"
UPLOAD_PREVIEW=0
RUN_UPLOAD=0
USE_KEYCHAIN_UPLOAD=0
STORE_KEYCHAIN_PASSWORD=0

usage() {
  cat <<'EOF'
Usage:
  scripts/prepare_workshop_upload.sh [--upload | --upload-via-keychain | --store-keychain-password]

Default behavior:
  - stages the mod files into build/steam/content/connected-settlements
  - swaps in Workshop-specific metadata from upload/steam/
  - generates build/steam/workshop_build_item.vdf

Optional behavior:
  --upload                 runs steamcmd after generating the VDF
  --upload-via-keychain    retrieves the Steam password from macOS Keychain and answers the SteamCMD password prompt
  --store-keychain-password
                           stores or updates the Steam password in macOS Keychain without printing it

Environment:
  STEAM_USERNAME          required for any upload/login action
  STEAM_KEYCHAIN_SERVICE  optional Keychain service name, defaults to civ7-steamcmd-upload
EOF
}

escape_vdf() {
  printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

xml_text() {
  local xml_file="$1"
  local tag="$2"
  /usr/bin/xmllint --xpath "string(//Row[@Tag='${tag}']/Text)" "$xml_file"
}

stage_mod_content() {
  rm -rf "$STAGED_MOD_DIR"
  mkdir -p "$STAGED_MOD_DIR"

  local required_paths=(
    "connected-settlements.modinfo"
    "ui"
    "text"
  )

  local path
  for path in "${required_paths[@]}"; do
    if [[ ! -e "${ROOT_DIR}/${path}" ]]; then
      echo "Missing required mod content: ${ROOT_DIR}/${path}" >&2
      exit 1
    fi
    rsync -a "${ROOT_DIR}/${path}" "$STAGED_MOD_DIR/"
  done

  mkdir -p "$STAGED_MOD_DIR/text/en_us"
  cp "$WORKSHOP_MODINFO_FILE" "$STAGED_MOD_DIR/connected-settlements.modinfo"
  cp "$WORKSHOP_MOD_TEXT_FILE" "$STAGED_MOD_DIR/text/en_us/ModInfoText.xml"
  cp "$WORKSHOP_INGAME_TEXT_FILE" "$STAGED_MOD_DIR/text/en_us/InGameText.xml"
}

persist_publishedfileid() {
  local new_id
  new_id="$(awk -F'"' '/"publishedfileid"/ { print $4 }' "$OUTPUT_VDF" | tail -n 1)"

  if [[ -z "$new_id" || "$new_id" == "$PUBLISHEDFILEID" ]]; then
    return
  fi

  if [[ -f "$CONFIG_FILE" ]]; then
    if grep -q '^PUBLISHEDFILEID=' "$CONFIG_FILE"; then
      perl -0pi -e "s/^PUBLISHEDFILEID=.*/PUBLISHEDFILEID=${new_id}/m" "$CONFIG_FILE"
    else
      printf '\nPUBLISHEDFILEID=%s\n' "$new_id" >>"$CONFIG_FILE"
    fi
  fi

  echo "Workshop item id: $new_id"
}

if [[ $# -gt 1 ]]; then
  usage
  exit 1
fi

if [[ $# -eq 1 ]]; then
  case "$1" in
    --upload)
      RUN_UPLOAD=1
      ;;
    --upload-via-keychain)
      RUN_UPLOAD=1
      USE_KEYCHAIN_UPLOAD=1
      ;;
    --store-keychain-password)
      STORE_KEYCHAIN_PASSWORD=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
fi

if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck source=/dev/null
  source "$CONFIG_FILE"
fi

if [[ ! -f "$LOCAL_MODINFO_FILE" ]]; then
  echo "Missing local mod manifest: $LOCAL_MODINFO_FILE" >&2
  exit 1
fi

required_workshop_files=(
  "$WORKSHOP_MODINFO_FILE"
  "$WORKSHOP_MOD_TEXT_FILE"
  "$WORKSHOP_INGAME_TEXT_FILE"
)

for workshop_file in "${required_workshop_files[@]}"; do
  if [[ ! -f "$workshop_file" ]]; then
    echo "Missing Workshop metadata file: $workshop_file" >&2
    exit 1
  fi
done

if [[ "$UPLOAD_PREVIEW" -eq 1 ]]; then
  if [[ ! -f "$PREVIEW_FILE" ]]; then
    echo "Missing preview file: $PREVIEW_FILE" >&2
    exit 1
  fi
fi

MOD_NAME="$(xml_text "$WORKSHOP_MOD_TEXT_FILE" LOC_MOD_CS_WORKSHOP_NAME)"
MOD_DESCRIPTION="$(xml_text "$WORKSHOP_MOD_TEXT_FILE" LOC_MOD_CS_WORKSHOP_DESCRIPTION)"

if [[ -z "$MOD_NAME" || -z "$MOD_DESCRIPTION" ]]; then
  echo "Could not extract workshop metadata from $WORKSHOP_MOD_TEXT_FILE" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
stage_mod_content

{
  printf '"workshopitem"\n'
  printf '{\n'
  printf '\t"appid" "%s"\n' "$(escape_vdf "$APP_ID")"
  printf '\t"publishedfileid" "%s"\n' "$(escape_vdf "$PUBLISHEDFILEID")"
  printf '\t"contentfolder" "%s"\n' "$(escape_vdf "$STAGED_MOD_DIR")"
  if [[ "$UPLOAD_PREVIEW" -eq 1 ]]; then
    printf '\t"previewfile" "%s"\n' "$(escape_vdf "$PREVIEW_FILE")"
  fi
  printf '\t"visibility" "%s"\n' "$(escape_vdf "$VISIBILITY")"
  printf '\t"title" "%s"\n' "$(escape_vdf "$MOD_NAME")"
  printf '\t"description" "%s"\n' "$(escape_vdf "$MOD_DESCRIPTION")"
  printf '\t"changenote" "%s"\n' "$(escape_vdf "$CHANGE_NOTE")"
  printf '}\n'
} >"$OUTPUT_VDF"

echo "Generated: $OUTPUT_VDF"
echo "Staged mod content: $STAGED_MOD_DIR"

if [[ "$STORE_KEYCHAIN_PASSWORD" -eq 1 ]]; then
  if [[ -z "${STEAM_USERNAME:-}" ]]; then
    echo "STEAM_USERNAME is required for --store-keychain-password." >&2
    exit 1
  fi

  security add-generic-password \
    -a "$STEAM_USERNAME" \
    -s "$KEYCHAIN_SERVICE" \
    -U \
    -T /usr/bin/security \
    -w
  echo "Stored or updated Steam password in macOS Keychain service: $KEYCHAIN_SERVICE"
  exit 0
fi

if [[ "$RUN_UPLOAD" -eq 0 ]]; then
  exit 0
fi

if ! command -v steamcmd >/dev/null 2>&1; then
  echo "steamcmd is not installed. Install via: brew install --cask steamcmd" >&2
  exit 1
fi

if [[ -z "${STEAM_USERNAME:-}" ]]; then
  echo "STEAM_USERNAME is required for upload." >&2
  exit 1
fi

if [[ "$USE_KEYCHAIN_UPLOAD" -eq 1 ]]; then
  if ! command -v expect >/dev/null 2>&1; then
    echo "expect is required for --upload-via-keychain and was not found." >&2
    exit 1
  fi

  if ! security find-generic-password -a "$STEAM_USERNAME" -s "$KEYCHAIN_SERVICE" >/dev/null 2>&1; then
    echo "No Keychain password found for account '$STEAM_USERNAME' and service '$KEYCHAIN_SERVICE'." >&2
    echo "Run: STEAM_USERNAME=$STEAM_USERNAME scripts/prepare_workshop_upload.sh --store-keychain-password" >&2
    exit 1
  fi

  echo "Running steamcmd via Keychain-backed password retrieval for user '$STEAM_USERNAME'."
  "${ROOT_DIR}/scripts/steamcmd_upload_with_keychain.expect" \
    "$STEAM_USERNAME" \
    "$KEYCHAIN_SERVICE" \
    "$OUTPUT_VDF"
else
  echo "Running steamcmd with cached-or-interactive login: +login $STEAM_USERNAME +workshop_build_item $OUTPUT_VDF +quit"
  steamcmd +login "$STEAM_USERNAME" +workshop_build_item "$OUTPUT_VDF" +quit
fi

persist_publishedfileid
