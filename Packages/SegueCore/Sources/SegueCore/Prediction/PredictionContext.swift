/// Where you are right now: the app in front, and the one you were in before it.
public struct PredictionContext: Equatable, Sendable {
    public var prev2: String?
    public var current: String

    public init(prev2: String?, current: String) {
        self.prev2 = prev2
        self.current = current
    }

    /// - Parameters:
    ///   - recent: saved events, oldest first.
    ///   - held: states the cleaner holds but hasn't saved yet, oldest first.
    ///   - heldSince: when the oldest held state started.
    ///   - current: the app in front now.
    public init(
        recent: [CleanEvent], held: [String], heldSince: Int64? = nil, current: String, now: Int64,
        sessionGapSeconds: Int64 = EventStore.defaultSessionGapSeconds
    ) {
        // Saved visits count only if the last one ended within the session gap of what follows it.
        let next = held.isEmpty ? now : (heldSince ?? now)
        var states: [String] = []
        if let last = recent.last, next - (last.ts + last.durationS) <= sessionGapSeconds {
            states = recent.map(\.state)
        }
        states += held + [current]

        var visits: [String] = []
        for state in states where visits.last != state {
            visits.append(state)
        }
        self.init(prev2: visits.count >= 2 ? visits[visits.count - 2] : nil, current: current)
    }
}
