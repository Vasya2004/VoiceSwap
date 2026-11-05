# Contributing

Issues and pull requests are welcome. Please keep changes focused, preserve
local-only transcription, and test on an Apple Silicon Mac running macOS 14 or
newer. See `AGENTS.md` for identifiers and installation invariants.

Before opening a pull request, run:

```bash
bash scripts/check.sh
swift run --package-path swift VoiceSwapCoreChecks
bash scripts/test-install.sh
python3 scripts/test-download.py
swift run -c debug --package-path swift Parakey --self-test all
SIGN_IDENTITY=- ./scripts/build-app.sh ./dist/VoiceSwap.app
```

The version in `swift/Info.plist` and `install-voiceswap.sh` must match
(`scripts/check.sh` enforces this). Release assets are immutable: bump the
version instead of replacing an existing ZIP. `scripts/prepare-release.sh`
derives the `v<version>` tag, archive, SHA-256 and `update.json` from that
single version.
