/// One "what came next" count. Empty strings mean "not used" and are never real states.
public struct TransitionKey: Hashable, Sendable {
    public var prev2: String
    public var prev1: String
    public var next: String
    /// A `TimeBucket` raw value, or `"any"`.
    public var timeBucket: String

    public init(prev2: String, prev1: String, next: String, timeBucket: String) {
        self.prev2 = prev2
        self.prev1 = prev1
        self.next = next
        self.timeBucket = timeBucket
    }
}

/// The counts an event adds to, from most to least specific. This one rule is shared by
/// live saving, rebuilding, and evaluation.
///
/// - Parameter previous: earlier events, oldest first.
/// - Returns: up to four keys. Earlier events separated by more than `sessionGapSeconds`
///   (sleep, overnight) do not count as context. The same state split by a short pause or lock
///   is one visit: continuing it adds no keys, and it counts once as context.
public func transitionKeys(for event: CleanEvent, previous: [CleanEvent], sessionGapSeconds: Int64) -> [TransitionKey] {
    struct Visit {
        var state: String
        var start: Int64
        var end: Int64
    }

    func connected(_ earlierEnd: Int64, _ laterStart: Int64) -> Bool {
        laterStart - earlierEnd <= sessionGapSeconds
    }

    var visits: [Visit] = []
    for earlier in previous {
        let end = earlier.ts + earlier.durationS
        if let last = visits.last, last.state == earlier.state, connected(last.end, earlier.ts) {
            visits[visits.count - 1].end = end
        } else {
            visits.append(Visit(state: earlier.state, start: earlier.ts, end: end))
        }
    }

    var prev1: Visit?
    var prev2: Visit?
    if let last = visits.last, connected(last.end, event.ts) {
        if last.state == event.state { return [] }
        prev1 = last
        if visits.count >= 2, connected(visits[visits.count - 2].end, last.start) {
            prev2 = visits[visits.count - 2]
        }
    }

    let bucket = event.timeBucket.rawValue
    var keys: [TransitionKey] = []
    if let prev1 {
        if let prev2 {
            keys.append(TransitionKey(prev2: prev2.state, prev1: prev1.state, next: event.state, timeBucket: bucket))
        }
        keys.append(TransitionKey(prev2: "", prev1: prev1.state, next: event.state, timeBucket: bucket))
        keys.append(TransitionKey(prev2: "", prev1: prev1.state, next: event.state, timeBucket: "any"))
    }
    keys.append(TransitionKey(prev2: "", prev1: "", next: event.state, timeBucket: "any"))
    return keys
}
