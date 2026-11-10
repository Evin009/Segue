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
        // TODO(you): write the predictor. Steps:
        //
        // 1. Read the 4 tiers from the store, most specific first:
        //      tier 1: store.weights(prev2: prev2, prev1: current, timeBucket: timeBucket.rawValue)  (skip if prev2 is nil)
        //      tier 2: store.weights(prev2: "", prev1: current, timeBucket: timeBucket.rawValue)
        //      tier 3: store.weights(prev2: "", prev1: current, timeBucket: "any")
        //      tier 4: store.weights(prev2: "", prev1: "", timeBucket: "any")
        //    Each returns [next state: weight].
        //
        // 2. Skip tiers 1–3 if their total weight is under config.minTierWeight.
        //
        // 3. For each tier, probability = weight / tier total.
        //    score = config.tierMultipliers[tier] × probability.
        //    A state keeps the score from the first tier it appears in.
        //    Also remember each state's plain probability (needed for step 6).
        //
        // 4. Remove `current` and anything in `dismissed`.
        //
        // 5. Sort by score, highest first; ties by state name (A before B).
        //
        // 6. If the top state's plain probability is under config.minProbability, return [].
        //
        // 7. Return the first config.limit as [Suggestion].
        return []
    }
}
