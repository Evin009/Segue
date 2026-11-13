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
    ///   - feedback: past accepts and dismisses while in `current`. Raises or lowers scores.
    public func predict(
        prev2: String?, current: String, timeBucket: TimeBucket,
        dismissed: Set<String> = [], feedback: [String: Feedback] = [:]
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
        // `base` is the back-off score alone; `score` also includes trust from feedback.
        var options: [String: (base: Double, score: Double, probability: Double)] = [:]
        for (tier, weights) in tiers.enumerated() {
            let total = weights.values.reduce(0, +)
            let isLastTier = tier == tiers.count - 1
            guard total > 0, isLastTier || total >= config.minTierWeight else { continue }

            for (state, weight) in weights where options[state] == nil {
                let probability = weight / total
                let base = config.tierMultipliers[tier] * probability
                let trust = feedback[state].map(Self.trust) ?? 1
                options[state] = (base, base * trust, probability)
            }
        }

        // 4. Drop current and dismissed.
        let candidates = options.filter { $0.key != current && !dismissed.contains($0.key) }

        // 6 first: is the best guess without feedback confident enough? Feedback only
        // reorders suggestions; it must never decide whether anything is shown.
        let bestBase = candidates.max { a, b in
            a.value.base != b.value.base ? a.value.base < b.value.base : a.key > b.key
        }
        guard let bestBase, bestBase.value.probability >= config.minProbability else {
            return []
        }

        // 5. Rank by score including feedback, ties by name.
        let ranked = candidates.sorted { a, b in
            a.value.score != b.value.score ? a.value.score > b.value.score : a.key < b.key
        }

        // 7. Top few.
        return ranked.prefix(config.limit).map { Suggestion(state: $0.key, score: $0.value.score) }
    }

    /// The bandit: how much to trust a suggestion, from accepts and dismisses.
    /// Beta-Bernoulli estimate of the accept rate, (accepts + 1) / (accepts + dismisses + 2),
    /// doubled so no feedback gives 1 and leaves the score unchanged.
    public static func trust(_ feedback: Feedback) -> Double {
        2 * Double(feedback.accepts + 1) / Double(feedback.accepts + feedback.dismisses + 2)
    }

    /// What the popup shows: predicts using feedback and recent dismissals saved in the store.
    public func suggest(prev2: String?, current: String, timeBucket: TimeBucket, at ts: Int64) throws -> [Suggestion] {
        try predict(
            prev2: prev2, current: current, timeBucket: timeBucket,
            dismissed: store.recentlyDismissed(after: current, at: ts),
            feedback: store.feedback(after: current)
        )
    }
}
