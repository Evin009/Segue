/// How well a guesser did on replayed history.
public struct EvalResult: Equatable, Sendable {
    /// Switches it had to guess: every move to a new state within a session.
    public var targets = 0
    /// Targets where it suggested anything at all.
    public var suggested = 0
    /// Targets where the first suggestion was right.
    public var top1Hits = 0
    /// Targets where the right state was in the first 3.
    public var top3Hits = 0

    public var top1Accuracy: Double { share(top1Hits) }
    public var top3Accuracy: Double { share(top3Hits) }
    public var coverage: Double { share(suggested) }

    private func share(_ count: Int) -> Double {
        targets == 0 ? 0 : Double(count) / Double(targets)
    }
}

/// Replays saved history in order. Before each switch, the guesser sees only what came before it,
/// as if it were running live. Staying quiet counts as a miss.
public enum Evaluator {
    public typealias Predict = (_ store: EventStore, _ prev2: String?, _ current: String, _ timeBucket: TimeBucket) throws -> [Suggestion]

    /// How many earlier events the store reads when counting. Kept the same here so replay matches.
    private static let lookback = 10

    public static func evaluate(
        _ events: [CleanEvent],
        sessionGapSeconds: Int64 = EventStore.defaultSessionGapSeconds,
        predict: Predict
    ) throws -> EvalResult {
        let store = try EventStore(path: nil, sessionGapSeconds: sessionGapSeconds)
        var result = EvalResult()

        for (i, event) in events.enumerated() {
            let earlier = Array(events[max(0, i - lookback)..<i])
            let keys = transitionKeys(for: event, previous: earlier, sessionGapSeconds: sessionGapSeconds)

            // Has a previous state: a real switch to guess. Keys are most specific first.
            if keys.count >= 3 {
                let prev1 = keys[keys.count - 2].prev1
                let prev2 = keys.count == 4 ? keys[0].prev2 : nil
                let guesses = try predict(store, prev2, prev1, event.timeBucket).map(\.state)

                result.targets += 1
                if !guesses.isEmpty { result.suggested += 1 }
                if guesses.first == event.state { result.top1Hits += 1 }
                if guesses.prefix(3).contains(event.state) { result.top3Hits += 1 }
            }

            try store.append(event)
        }
        return result
    }

    public static func predictor(_ store: EventStore, _ prev2: String?, _ current: String, _ timeBucket: TimeBucket) throws -> [Suggestion] {
        try Predictor(store: store).predict(prev2: prev2, current: current, timeBucket: timeBucket)
    }

    public static func baseline(_ store: EventStore, _ prev2: String?, _ current: String, _ timeBucket: TimeBucket) throws -> [Suggestion] {
        try BaselinePredictor(store: store).predict(current: current)
    }
}
