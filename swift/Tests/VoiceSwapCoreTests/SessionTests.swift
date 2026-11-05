import XCTest
import VoiceSwapChecks

final class SessionTests: XCTestCase {
    @MainActor func testInsertionRaces() async throws { try await runInsertionChecks() }
    func testCoreInvariants() throws { try runCoreChecks() }
}
