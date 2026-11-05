import Foundation

public enum DictationPhase: Equatable, Sendable {
    case preparing, ready, recording, transcribing, result, error
}

/// UI and async work share one session owner. Cancellation invalidates all late completions.
public struct DictationSession: Sendable {
    public private(set) var phase: DictationPhase = .preparing
    public private(set) var id: UUID?
    public var ready = false {
        didSet {
            if phase == .preparing || phase == .ready { phase = ready ? .ready : .preparing }
        }
    }
    public init() {}
    public var recording: Bool {
        get { phase == .recording }
        set {
            if newValue { phase = .recording }
            else if phase == .recording { phase = ready ? .ready : .preparing }
        }
    }
    public var busy: Bool {
        get { phase == .transcribing }
        set {
            if newValue { phase = .transcribing }
            else if phase == .transcribing { id = nil; phase = ready ? .ready : .preparing }
        }
    }
    @discardableResult public mutating func begin() -> UUID {
        let token = UUID()
        id = token
        phase = .recording
        return token
    }
    public func accepts(_ token: UUID?) -> Bool { token != nil && token == id }
    public mutating func cancel() { id = nil; phase = ready ? .ready : .preparing }
    public mutating func finish(failed: Bool = false) { id = nil; phase = failed ? .error : .result }
}

public enum InsertionOutcome: Equatable, Sendable {
    case blocked, notDispatched, dispatched, confirmed
}

public enum HUDMotion {
    public static let openingSeconds = 0.22
    public static let closingSeconds = 0.32
    public static func progress(_ value: Double) -> Double {
        let t = min(1, max(0, value))
        return t * t * t * (t * (t * 6 - 15) + 10)
    }
}

public struct DownloadBudget: Sendable {
    public enum Failure: Error { case tooLarge }
    private let maximum: Int
    public private(set) var received = 0
    public init(maximum: Int) { self.maximum = max(0, maximum) }
    public mutating func accept(_ count: Int) throws {
        guard count >= 0, count <= maximum - received else { throw Failure.tooLarge }
        received += count
    }
}
