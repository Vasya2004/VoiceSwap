#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

bash -n install-voiceswap.sh scripts/build-app.sh scripts/check.sh scripts/package-model.sh
plutil -lint swift/Info.plist entitlements.plist

app_version="$(plutil -extract CFBundleShortVersionString raw -o - swift/Info.plist)"
installer_version="$(sed -n 's/^VERSION="${VOICESWAP_VERSION:-\([^}]*\)}"$/\1/p' install-voiceswap.sh)"
[[ -n "$installer_version" && "$app_version" == "$installer_version" ]] || {
    printf 'Version mismatch: Info.plist=%s install-voiceswap.sh=%s\n' "$app_version" "$installer_version" >&2
    exit 1
}

grep -q 'com.apple.security.device.audio-input' entitlements.plist
grep -q 'com.apple.security.device.microphone' entitlements.plist

grep -q 'raw.githubusercontent.com/Vasya2004/VoiceSwap/main/install-voiceswap.sh' README.md
grep -q 'com.vasya2004.voiceswap' swift/Info.plist
grep -q 'VoiceSwap.icns' scripts/build-app.sh
grep -q 'Restarting the build natively for Apple Silicon' scripts/build-app.sh
grep -q 'validate_output_app_path "$OUTPUT_APP"' scripts/build-app.sh
grep -q 'EXPECTED_CONTENT_SHA256=' scripts/package-model.sh

settings_save_handler="$(sed -n '/@objc private func saveSettingsClicked/,/private func captureAISettingsFields/p' swift/Sources/Parakey/main.swift)"
grep -Fq 'settingsWindow?.performClose(sender)' <<<"$settings_save_handler" || {
    printf 'Settings save handler must close the settings window after a successful save.\n' >&2
    exit 1
}

git diff --check
printf 'VoiceSwap checks passed (v%s).\n' "$app_version"
