#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VOICESWAP_LIBRARY_ONLY=1 source "$ROOT_DIR/install-voiceswap.sh"
purge=0
case "${1:-}" in
    '') ;;
    --purge-data) purge=1 ;;
    *) printf 'Usage: %s [--purge-data]\n' "$0"; exit 1 ;;
esac
app="$(voice_app_path)"
voice_validate_path "$app"
if [[ -e "$app" ]]; then voice_verify_bundle "$app"; fi
voice_stop "$app"
rm -f "$HOME/Library/LaunchAgents/com.vasya2004.voiceswap.agent.plist"
rm -rf "$app"
if [[ "$purge" == 1 ]]; then
    support="$HOME/Library/Application Support/VoiceSwap"
    # Keep backups even when purging user data. Shared FluidAudio models are not owned exclusively by this app.
    if [[ -d "$support" ]]; then
        find "$support" -mindepth 1 -maxdepth 1 ! -name Backups -exec rm -rf {} +
    fi
    defaults delete com.vasya2004.voiceswap >/dev/null 2>&1 || true
    rm -rf "$HOME/Library/Caches/com.vasya2004.voiceswap" "$HOME/Library/Saved Application State/com.vasya2004.voiceswap.savedState"
    rm -f "$HOME/Library/Logs/SuperDictate.log" "$HOME/Library/Logs/SuperDictate-agent.launchd.log" "$HOME/Library/Logs/VoiceSwap-update.log"
fi
printf 'VoiceSwap removed. Source code, backups, shared models and Keychain items were preserved.\n'
