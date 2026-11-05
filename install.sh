#!/bin/bash
# Legacy entry point kept for old links. VoiceSwap has one installer:
# install-voiceswap.sh (bundle id com.vasya2004.voiceswap, ~/Applications/VoiceSwap.app).
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
if [[ -n "$ROOT_DIR" && -f "$ROOT_DIR/install-voiceswap.sh" ]]; then
    exec bash "$ROOT_DIR/install-voiceswap.sh" "$@"
fi
curl -fsSL https://raw.githubusercontent.com/Vasya2004/VoiceSwap/main/install-voiceswap.sh | bash
