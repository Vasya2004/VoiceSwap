#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VOICESWAP_LIBRARY_ONLY=1 source "$ROOT_DIR/install-voiceswap.sh"
TEST_DIR="$(mktemp -d)"
trap 'rm -rf "$TEST_DIR"' EXIT
export VOICESWAP_BACKUP_DIR="$TEST_DIR/backups"
mkdir -p "$TEST_DIR/VoiceSwap.app" "$TEST_DIR/staged/VoiceSwap.app"
printf old > "$TEST_DIR/VoiceSwap.app/version"
printf new > "$TEST_DIR/staged/VoiceSwap.app/version"
# Transaction unit test: no real applications or services are launched/stopped.
voice_verify_bundle() { [[ -f "$1/version" ]]; }
voice_stop() { :; }
voice_start_and_check() { [[ "$(cat "$1/version")" == old ]]; }
if voice_install_bundle "$TEST_DIR/staged/VoiceSwap.app" "$TEST_DIR/VoiceSwap.app"; then
    echo 'Expected startup failure' >&2; exit 1
fi
[[ "$(cat "$TEST_DIR/VoiceSwap.app/version")" == old ]]
voice_start_and_check() { :; }
voice_install_bundle "$TEST_DIR/staged/VoiceSwap.app" "$TEST_DIR/VoiceSwap.app"
[[ "$(cat "$TEST_DIR/VoiceSwap.app/version")" == new ]]
voice_verify_bundle() { return 1; }
if voice_install_bundle "$TEST_DIR/staged/VoiceSwap.app" "$TEST_DIR/VoiceSwap.app"; then exit 1; fi
[[ "$(cat "$TEST_DIR/VoiceSwap.app/version")" == new ]]
if voice_validate_path /; then exit 1; fi
printf 'PASS installer: rollback, replacement, invalid bundle, unsafe path\n'
