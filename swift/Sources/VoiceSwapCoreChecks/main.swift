import Foundation
import VoiceSwapChecks

do {
    try runCoreChecks()
    try await runInsertionChecks()
    print("PASS isolated core checks (no microphone, preferences or clipboard access)")
} catch {
    fputs("FAIL core checks: \(error)\n", stderr)
    exit(1)
}
