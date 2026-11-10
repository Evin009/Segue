/// Predictor settings. Values from PLAN.md.
public struct PredictorConfig: Sendable {
    /// Tiers 1–3 are used only if their total weight is at least this.
    public var minTierWeight: Double = 5
    /// Score = multiplier × probability, for tiers 1–4.
    public var tierMultipliers: [Double] = [1, 0.4, 0.16, 0.064]
    /// Suggest nothing if the top option's plain probability is under this.
    public var minProbability: Double = 0.2
    public var limit: Int = 3

    public static let standard = PredictorConfig()
}

/// Guesses what you'll open next from your last two states and the time of day.
public struct Predictor: Sendable {
    private let store: EventStore
    private let config: PredictorConfig

    public init(store: EventStore, config: PredictorConfig = .standard) {
        self.store = store
        self.config = config
    }

    /// - Parameters:
    ///   - prev2: the state before `current`, if any.
    ///   - current: the state you're in now. Never suggested.
    ///   - dismissed: states dismissed here in the last 4 hours. Never suggested.
    public func predict(
        prev2: String?, current: String, timeBucket: TimeBucket, dismissed: Set<String> = []
    ) throws -> [Suggestion] {
        // 1. The 4 tiers, most specific first. Each is [next state: weight].
        let bucket = timeBucket.rawValue
        let tiers: [[String: Double]] = [
            try prev2.map { try store.weights(prev2: $0, prev1: current, timeBucket: bucket) } ?? [:],
            try store.weights(prev2: "", prev1: current, timeBucket: bucket),
            try store.weights(prev2: "", prev1: current, timeBucket: "any"),
            try store.weights(prev2: "", prev1: "", timeBucket: "any"),
        ]

        // 2–3. Score each state from the first tier it appears in.
        var options: [String: (score: Double, probability: Double)] = [:]
        for (tier, weights) in tiers.enumerated() {
            let total = weights.values.reduce(0, +)
            let isLastTier = tier == tiers.count - 1
            guard total > 0, isLastTier || total >= config.minTierWeight else { continue }

            for (state, weight) in weights where options[state] == nil {
                let probability = weight / total
                options[state] = (config.tierMultipliers[tier] * probability, probability)
            }
        }

        // 4–5. Drop current and dismissed, then rank by score, ties by name.
        let ranked = options
            .filter { $0.key != current && !dismissed.contains($0.key) }
            .sorted { a, b in
                a.value.score != b.value.score ? a.value.score > b.value.score : a.key < b.key
            }

        // 6. Not confident enough: suggest nothing.
        guard let top = ranked.first, top.value.probability >= config.minProbability else {
            return []
        }

        // 7. Top few.
        return ranked.prefix(config.limit).map { Suggestion(state: $0.key, score: $0.value.score) }
    }
}
