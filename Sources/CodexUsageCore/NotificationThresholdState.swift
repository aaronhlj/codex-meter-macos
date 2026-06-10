import Foundation

public enum UsageWindowKind: Hashable, Sendable {
    case primary
    case secondary
}

public struct NotificationThresholdState: Sendable {
    private struct WindowState: Sendable {
        var resetAt: Date?
        var emitted: Set<Int> = []
    }

    private var states: [UsageWindowKind: WindowState] = [:]

    public init() {}

    public mutating func crossedThresholds(
        window: UsageWindowKind,
        remaining: Int,
        resetAt: Date?
    ) -> [Int] {
        var state = states[window] ?? WindowState()
        if state.resetAt != resetAt {
            state = WindowState(resetAt: resetAt)
        }

        let crossed = [20, 10].filter { remaining < $0 && !state.emitted.contains($0) }
        state.emitted.formUnion(crossed)
        states[window] = state
        return crossed
    }
}
