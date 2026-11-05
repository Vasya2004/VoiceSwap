import Foundation

/// The side effects are injected so focus races can be verified without sending real keystrokes.
@MainActor
public enum InsertionTransaction {
    public static func perform(
        text: String, sendReturn: Bool, delayMilliseconds: Int,
        canStart: () -> Bool, isCurrent: () -> Bool, targetMatches: () -> Bool,
        readText: () -> String?, dispatchOnce: () -> Bool, postReturn: () -> Bool,
        now: () -> Double = { ProcessInfo.processInfo.systemUptime },
        pause: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) async -> InsertionOutcome {
        guard isCurrent(), canStart() else { return .blocked }
        let before = readText()
        guard dispatchOnce() else { return .dispatched }
        let deadline = now() + 1
        var confirmed = false
        while now() < deadline {
            guard isCurrent(), targetMatches() else { return .dispatched }
            if let value = readText(), value != before,
               value.contains(text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                confirmed = true
                break
            }
            do { try await pause(20_000_000) } catch { return .dispatched }
        }
        guard confirmed else { return .dispatched }
        if sendReturn {
            do { try await pause(UInt64(max(0, delayMilliseconds)) * 1_000_000) }
            catch { return .dispatched }
            guard isCurrent(), targetMatches(), postReturn() else { return .dispatched }
        }
        return .confirmed
    }
}
