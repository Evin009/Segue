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
///   (sleep, overnight) do not count as context.
public func transitionKeys(for event: CleanEvent, previous: [CleanEvent], sessionGapSeconds: Int64) -> [TransitionKey] {
    func connected(_ earlier: CleanEvent, _ later: CleanEvent) -> Bool {
        later.ts - (earlier.ts + earlier.durationS) <= sessionGapSeconds
    }

    let bucket = event.timeBucket.rawValue
    var prev1: CleanEvent?
    var prev2: CleanEvent?
    if let last = previous.last, connected(last, event) {
        prev1 = last
        if previous.count >= 2, connected(previous[previous.count - 2], last) {
            prev2 = previous[previous.count - 2]
        }
    }

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
