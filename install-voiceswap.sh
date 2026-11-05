#!/bin/bash
set -euo pipefail

voice_fail() { printf 'VoiceSwap: %s\n' "$*" >&2; return 1; }
voice_app_path() {
    if [[ -n "${VOICESWAP_APP_PATH:-}" ]]; then printf '%s\n' "$VOICESWAP_APP_PATH"
    elif [[ -d "$HOME/Applications/VoiceSwap.app" ]]; then printf '%s\n' "$HOME/Applications/VoiceSwap.app"
    elif [[ -d /Applications/VoiceSwap.app ]]; then printf '%s\n' /Applications/VoiceSwap.app
    else printf '%s\n' "$HOME/Applications/VoiceSwap.app"; fi
}
voice_validate_path() {
    [[ "$1" = /*/VoiceSwap.app && ! -L "$1" && ! -L "$(dirname "$1")" ]] || voice_fail 'Unsafe application path.'
}
voice_verify_bundle() {
    local app="$1" version="${2:-}"
    [[ -x "$app/Contents/MacOS/SuperDictate" ]] || return 1
    [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$app/Contents/Info.plist")" == com.vasya2004.voiceswap ]] || return 1
    if [[ -n "$version" ]]; then
        [[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")" == "$version" ]] || return 1
    fi
    [[ -z "$(find "$app" -type l -print -quit)" ]] || return 1
    file "$app/Contents/MacOS/SuperDictate" | grep -q arm64 || return 1
    codesign --verify --deep --strict "$app" || return 1
    codesign -d --entitlements :- "$app" 2>/dev/null | grep -q 'com.apple.security.device.audio-input' || return 1
}
voice_stop() {
    local escaped count
    launchctl bootout "gui/$(id -u)/com.vasya2004.voiceswap.agent" >/dev/null 2>&1 || true
    escaped="$(printf '%s' "$1/Contents/MacOS/SuperDictate" | sed 's/[][\.^$*+?(){}|]/\\&/g')"
    pkill -f "^${escaped}( --agent)?$" >/dev/null 2>&1 || true
    for count in {1..40}; do
        if ! pgrep -f "^${escaped}( --agent)?$" >/dev/null 2>&1; then return 0; fi
        sleep 0.25
    done
    voice_fail 'Application did not stop; its files were not replaced.'
}
voice_start_and_check() {
    open "$1" || return 1
    if [[ "$(defaults read com.vasya2004.voiceswap agent_enabled 2>/dev/null || true)" == 0 ]]; then return 0; fi
    local agent_plist="$HOME/Library/LaunchAgents/com.vasya2004.voiceswap.agent.plist"
    if [[ -f "$agent_plist" ]]; then
        launchctl bootstrap "gui/$(id -u)" "$agent_plist" >/dev/null 2>&1 || true
        launchctl kickstart "gui/$(id -u)/com.vasya2004.voiceswap.agent" >/dev/null 2>&1 || true
    fi
    local count status_file="$HOME/Library/Application Support/VoiceSwap/AgentStatus.json" state_pid running_pid
    for count in {1..30}; do
        running_pid="$(launchctl print "gui/$(id -u)/com.vasya2004.voiceswap.agent" 2>/dev/null | sed -n 's/^[[:space:]]*pid = //p' | head -1)"
        if [[ -n "$running_pid" && -f "$status_file" ]]; then
            state_pid="$(plutil -extract pid raw -o - "$status_file" 2>/dev/null || true)"
            if [[ "$running_pid" == "$state_pid" ]] && kill -0 "$running_pid" 2>/dev/null; then return 0; fi
        fi
        sleep 1
    done
    voice_fail 'The new background service did not start.'
}
voice_install_bundle() {
    local staged="$1" app="$2" version="${3:-}" parent transaction previous backup_dir backup
    voice_validate_path "$app" || return 1
    voice_verify_bundle "$staged" "$version" || { voice_fail 'Bundle verification failed.'; return 1; }
    parent="$(dirname "$app")"
    mkdir -p "$parent"
    transaction="$(mktemp -d "$parent/.voiceswap-install.XXXXXX")"
    previous="$transaction/previous.app"
    if ! ditto "$staged" "$transaction/VoiceSwap.app" || ! voice_verify_bundle "$transaction/VoiceSwap.app" "$version"; then
        rm -rf "$transaction"; return 1
    fi
    if [[ -d "$app" ]]; then
        backup_dir="${VOICESWAP_BACKUP_DIR:-$HOME/Library/Application Support/VoiceSwap/Backups}"
        mkdir -p "$backup_dir"
        backup="$backup_dir/VoiceSwap-$(date +%Y%m%d-%H%M%S)-$$-$RANDOM.zip"
        if ! ditto -c -k --sequesterRsrc --keepParent "$app" "$backup"; then rm -rf "$transaction"; return 1; fi
        printf 'Backup: %s\n' "$backup"
    fi
    voice_stop "$app" || { rm -rf "$transaction"; return 1; }
    if [[ -e "$app" ]] && ! mv "$app" "$previous"; then rm -rf "$transaction"; return 1; fi
    if mv "$transaction/VoiceSwap.app" "$app" && voice_start_and_check "$app"; then
        rm -rf "$transaction"
        printf 'VoiceSwap: installed and started %s\n' "$app"
        return 0
    fi
    voice_stop "$app" || { voice_fail "Rollback pending; previous bundle retained at $previous"; return 1; }
    rm -rf "$app"
    if [[ -d "$previous" ]]; then
        mv "$previous" "$app"
        voice_start_and_check "$app" || true
    fi
    rm -rf "$transaction"
    voice_fail 'Installation failed; previous application restored when available.'
}

if [[ "${VOICESWAP_LIBRARY_ONLY:-0}" == 1 ]]; then return 0; fi
REPOSITORY="${VOICESWAP_REPOSITORY:-Vasya2004/VoiceSwap}"
VERSION="${VOICESWAP_VERSION:-0.3.5}"
APP_PATH="$(voice_app_path)"
[[ "$(uname -s)" == Darwin && "$(uname -m)" == arm64 ]] || { voice_fail 'Apple Silicon macOS required.'; exit 1; }
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ]] || exit 1
ARCHIVE_URL="${VOICESWAP_ARCHIVE_URL:-https://github.com/$REPOSITORY/releases/download/v$VERSION/VoiceSwap.zip}"
CHECKSUM_URL="${VOICESWAP_CHECKSUM_URL:-$ARCHIVE_URL.sha256}"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voiceswap-install.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
curl --fail --location --show-error --max-filesize 67108864 --retry 3 "$ARCHIVE_URL" -o "$WORK_DIR/VoiceSwap.zip"
EXPECTED_SHA="$(curl --fail --location --show-error --max-filesize 4096 "$CHECKSUM_URL" | awk 'NR == 1 {print $1}')"
[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{64}$ ]] || exit 1
[[ "$(shasum -a 256 "$WORK_DIR/VoiceSwap.zip" | awk '{print $1}')" == "$EXPECTED_SHA" ]] || { voice_fail 'Checksum mismatch.'; exit 1; }
ditto -x -k "$WORK_DIR/VoiceSwap.zip" "$WORK_DIR/unpacked"
voice_install_bundle "$WORK_DIR/unpacked/VoiceSwap.app" "$APP_PATH" "$VERSION"
