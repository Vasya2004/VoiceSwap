import Foundation
import VoiceSwapCore

public enum CheckFailure: Error { case failed(String) }
public func runCoreChecks() throws {
    func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure.failed(message) }
    }
    var session = DictationSession()
    session.ready = true
    let first = session.begin()
    session.busy = true
    session.recording = false
    try expect(session.busy && session.accepts(first), "Sleep cleanup must not erase ongoing transcription")
    session.cancel()
    try expect(!session.accepts(first) && session.phase == .ready, "Cancelled work must be rejected")
    let second = session.begin()
    try expect(!session.accepts(first) && session.accepts(second), "A new session must reject old completions")
    session.finish()
    try expect(!session.accepts(second) && session.phase == .result, "Completed work must be rejected")
    _ = session.begin()
    session.ready = false
    try expect(session.recording, "Readiness changes must not erase an active recording")
    session.cancel()
    try expect(session.phase == .preparing, "Cancellation without permission must return to preparing")
    var previous = 0.0
    for step in 0...1000 {
        let value = HUDMotion.progress(Double(step) / 1000)
        try expect(value >= previous && value <= 1, "Morph must be monotonic and bounded")
        previous = value
    }
    try expect(HUDMotion.progress(-1) == 0 && HUDMotion.progress(2) == 1, "Clamp progress")
    try expect(HUDMotion.openingSeconds == 0.22 && HUDMotion.closingSeconds == 0.32, "Preserve animation timing")
    var limit = DownloadBudget(maximum: 16)
    try limit.accept(8)
    try limit.accept(8)
    do { try limit.accept(1); throw CheckFailure.failed("Oversized download accepted") }
    catch DownloadBudget.Failure.tooLarge { }
}

@MainActor
public func runInsertionChecks() async throws {
    func expect(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure.failed(message) }
    }
    // Each scenario uses an in-memory field; no real pasteboard, AX API or keyboard.
    for scenario in ["blocked", "confirmed", "uncertain", "focusAfterDispatch", "focusBeforeReturn", "cancelBeforeReturn", "partialDispatch"] {
        var field = ""
        var matches = scenario != "blocked"
        var current = true
        var dispatches = 0
        var returns = 0
        var time = 0.0
        let outcome = await InsertionTransaction.perform(
            text: "hello", sendReturn: true, delayMilliseconds: 100,
            canStart: { matches }, isCurrent: { current }, targetMatches: { matches },
            readText: { field },
            dispatchOnce: {
                dispatches += 1
                if scenario != "uncertain" { field = "hello" }
                if scenario == "focusAfterDispatch" { matches = false }
                return scenario != "partialDispatch"
            },
            postReturn: { returns += 1; return true },
            now: { time },
            pause: { nanos in
                time += Double(nanos) / 1_000_000_000
                if scenario == "focusBeforeReturn" { matches = false }
                if scenario == "cancelBeforeReturn" { current = false }
            }
        )
        if scenario == "blocked" {
            try expect(outcome == .blocked && dispatches == 0 && returns == 0, "Changed target must block all effects")
        } else if scenario == "confirmed" {
            try expect(outcome == .confirmed && dispatches == 1 && returns == 1, "Confirmed insertion should send once")
        } else {
            try expect(outcome == .dispatched && dispatches == 1 && returns == 0, "Uncertain/cancelled insertion must never retry or send Return: \(scenario)")
        }
    }
}
