# VoiceSwap development invariants

- Bundle identifier: `com.vasya2004.voiceswap`; agent: `com.vasya2004.voiceswap.agent`.
- Update the existing installation. On this Mac it is `~/Applications/VoiceSwap.app`.
- Use `scripts/install-local.sh`. Verify the staged bundle before stopping the old app;
  preserve a backup and roll back if the replacement cannot start.
- Never launch temporary, copied or test app bundles. Use command-line diagnostics.
- Preserve an existing certificate signing identity. `VOICESWAP_SIGN_IDENTITY` selects
  a configured identity; an ad-hoc local build is supported when no certificate exists.
  It may require granting macOS permissions again. Never reset TCC automatically.
- Never open more than one privacy pane at a time.
- Preserve source code, backups, preference keys and the existing Keychain service.
- Run `swift run --package-path swift VoiceSwapCoreChecks` for isolated tests.
  `swift test --package-path swift` runs the same checks with XCTest when Xcode exists.
- `Parakey --self-test all` is an explicit integration suite: it uses named test
  pasteboards, temporary preferences, signed synthetic bundles, and model verification.
  It must never launch those synthetic bundles.
- Run `bash scripts/check.sh` and `bash scripts/test-install.sh` before installation.
