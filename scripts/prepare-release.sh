#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:?App path required}"
OUTPUT="${2:?Output directory required}"
version="$(plutil -extract CFBundleShortVersionString raw -o - "$ROOT_DIR/swift/Info.plist")"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || exit 1
VOICESWAP_LIBRARY_ONLY=1 source "$ROOT_DIR/install-voiceswap.sh"
voice_verify_bundle "$APP" "$version"
if [[ "${GITHUB_REF_TYPE:-}" == tag && "${GITHUB_REF_NAME:-}" != "v$version" ]]; then
    voice_fail 'Tag does not match application version.'; exit 1
fi
mkdir -p "$OUTPUT"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUTPUT/VoiceSwap.zip"
(cd "$OUTPUT" && shasum -a 256 VoiceSwap.zip > VoiceSwap.zip.sha256)
sha="$(awk '{print $1}' "$OUTPUT/VoiceSwap.zip.sha256")"
printf '{\n  "version": "%s",\n  "sha256": "%s"\n}\n' "$version" "$sha" > "$OUTPUT/update.json"
printf 'v%s\n' "$version" > "$OUTPUT/tag.txt"
printf 'Prepared v%s (not published)\n' "$version"
