#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VOICESWAP_LIBRARY_ONLY=1 source "$ROOT_DIR/install-voiceswap.sh"
APP_PATH="$(voice_app_path)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voiceswap-local.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
identity="${VOICESWAP_SIGN_IDENTITY:-}"
if [[ -z "$identity" && -d "$APP_PATH" ]]; then
    identity="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1 | sed -n 's/^Authority=//p' | head -1)"
fi
identity="${identity:--}"
if [[ "$identity" == '-' ]]; then
    printf 'VoiceSwap: ad-hoc local build; macOS may require permissions again.\n'
fi
SIGN_IDENTITY="$identity" "$ROOT_DIR/scripts/build-app.sh" "$WORK_DIR/VoiceSwap.app"
if [[ -d "$APP_PATH" ]] && codesign -dv --verbose=4 "$APP_PATH" 2>&1 | grep -q '^Authority='; then
    old="$(codesign -d -r- "$APP_PATH" 2>&1 | tail -1)"
    new="$(codesign -d -r- "$WORK_DIR/VoiceSwap.app" 2>&1 | tail -1)"
    [[ "$old" == "$new" ]] || { voice_fail 'Refusing to change the installed signing identity.'; exit 1; }
fi
export VOICESWAP_BACKUP_DIR="$ROOT_DIR/backups"
voice_install_bundle "$WORK_DIR/VoiceSwap.app" "$APP_PATH"
