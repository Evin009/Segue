/// The simple guess to beat: your most-used states overall, ignoring context.
public struct BaselinePredictor: Sendable {
    private let store: EventStore
    private let limit: Int

    public init(store: EventStore, limit: Int = 3) {
        self.store = store
        self.limit = limit
    }

    /// Top states by share of all visits, skipping the one you're in. Ties sorted by name.
    public func predict(current: String) throws -> [Suggestion] {
        let weights = try store.weights(prev2: "", prev1: "", timeBucket: "any")
        let total = weights.values.reduce(0, +)
        guard total > 0 else { return [] }
        return weights
            .filter { $0.key != current }
            .map { Suggestion(state: $0.key, score: $0.value / total) }
            .sorted { $0.score != $1.score ? $0.score > $1.score : $0.state < $1.state }
            .prefix(limit)
            .map { $0 }
    }
}

// CEN 4020 - Software Engineering Credit(s): 3
// CIS 4930 - tools in workfoce
