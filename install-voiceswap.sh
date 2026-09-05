#!/bin/bash

set -euo pipefail

REPOSITORY="${VOICESWAP_REPOSITORY:-Vasya2004/VoiceSwap}"
VERSION="${VOICESWAP_VERSION:-0.3.4}"
APP_PATH="${VOICESWAP_APP_PATH:-/Applications/VoiceSwap.app}"
AGENT_LABEL="com.vasya2004.voiceswap.agent"
ARCHIVE_URL="${VOICESWAP_ARCHIVE_URL:-https://github.com/$REPOSITORY/releases/download/v$VERSION/VoiceSwap.zip}"
CHECKSUM_URL="${VOICESWAP_CHECKSUM_URL:-$ARCHIVE_URL.sha256}"

say() { printf '\033[1;36mVoiceSwap:\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31mVoiceSwap:\033[0m %s\n' "$*" >&2; exit 1; }

[[ "$(uname -s)" == "Darwin" ]] || fail "VoiceSwap works only on macOS."
[[ "$(uname -m)" == "arm64" ]] || fail "VoiceSwap requires an Apple Silicon Mac (M1 or newer)."
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 14 ]] || fail "VoiceSwap requires macOS 14 or newer."

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/voiceswap-install.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT
ARCHIVE="$WORK_DIR/VoiceSwap.zip"

say "Downloading VoiceSwap ${VERSION}…"
curl --fail --location --show-error --retry 3 "$ARCHIVE_URL" -o "$ARCHIVE"
EXPECTED_SHA="$(curl --fail --location --show-error --retry 3 "$CHECKSUM_URL" | awk 'NR == 1 { print $1 }')"
[[ "$EXPECTED_SHA" =~ ^[0-9a-f]{64}$ ]] || fail "The release checksum is invalid."
ACTUAL_SHA="$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')"
[[ "$ACTUAL_SHA" == "$EXPECTED_SHA" ]] || fail "The downloaded archive did not match its checksum."

ditto -x -k "$ARCHIVE" "$WORK_DIR/unpacked"
STAGED_APP="$WORK_DIR/unpacked/VoiceSwap.app"
[[ -x "$STAGED_APP/Contents/MacOS/SuperDictate" ]] || fail "The archive does not contain VoiceSwap.app."
[[ "$(plutil -extract CFBundleIdentifier raw -o - "$STAGED_APP/Contents/Info.plist")" == "com.vasya2004.voiceswap" ]] || fail "The app bundle identifier is invalid."
[[ "$(plutil -extract CFBundleShortVersionString raw -o - "$STAGED_APP/Contents/Info.plist")" == "$VERSION" ]] || fail "The app version is not the requested release."
codesign --verify --deep --strict "$STAGED_APP" || fail "The app signature check failed."

say "Installing VoiceSwap in Applications…"
USER_ID="$(id -u)"
launchctl bootout "gui/$USER_ID/$AGENT_LABEL" >/dev/null 2>&1 || true
pkill -f '/Applications/VoiceSwap.app/Contents/MacOS/SuperDictate' >/dev/null 2>&1 || true
INCOMING="/Applications/.VoiceSwap.incoming.$USER_ID"
BACKUP="/Applications/.VoiceSwap.backup.$USER_ID"
[[ ! -e "$INCOMING" && ! -e "$BACKUP" ]] || fail "A previous VoiceSwap installation is still being finalized."
ditto "$STAGED_APP" "$INCOMING"
if [[ -e "$APP_PATH" ]]; then mv "$APP_PATH" "$BACKUP"; fi
if ! mv "$INCOMING" "$APP_PATH"; then
  [[ -e "$BACKUP" ]] && mv "$BACKUP" "$APP_PATH"
  fail "Could not install VoiceSwap; the previous app was restored."
fi
[[ -e "$BACKUP" ]] && rm -rf "$BACKUP"
open "$APP_PATH"
say "Installed. On first launch, allow Microphone, Accessibility, and Input Monitoring."
