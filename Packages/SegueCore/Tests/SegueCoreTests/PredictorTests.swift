import Foundation
import Testing
@testable import SegueCore

private func predict(
    _ store: EventStore, prev2: String?, current: String,
    bucket: TimeBucket = .afternoon, dismissed: Set<String> = []
) throws -> [Suggestion] {
    try Predictor(store: store).predict(prev2: prev2, current: current, timeBucket: bucket, dismissed: dismissed)
}

// MARK: - Tiers

@Test func usesLastTwoWhenEnoughData() throws {
    // After X then A comes B. After Y then A comes C.
    let store = try storeWith(sessions: repeated(5, .afternoon, ["X", "A", "B"]) + repeated(5, .afternoon, ["Y", "A", "C"]))
    #expect(try predict(store, prev2: "X", current: "A").first?.state == "B")
    #expect(try predict(store, prev2: "Y", current: "A").first?.state == "C")
}

@Test func keepsScoreFromFirstTierItAppearsIn() throws {
    // B is in tier 1 (probability 1.0) and tier 4. It keeps the tier 1 score.
    let store = try storeWith(sessions: repeated(5, .afternoon, ["X", "A", "B"]))
    let first = try #require(try predict(store, prev2: "X", current: "A").first)
    #expect(first.state == "B")
    #expect(first.score == 1.0)
}

@Test func skipsTierWithUnderFiveWeight() throws {
    // (X, A) seen only 4 times, so tier 1 is skipped. Tier 2: after A, B 4 of 5, C 1 of 5.
    let store = try storeWith(sessions: repeated(4, .afternoon, ["X", "A", "B"]) + repeated(1, .afternoon, ["Y", "A", "C"]))
    let suggestions = try predict(store, prev2: "X", current: "A")
    #expect(suggestions.map(\.state) == ["B", "C", "X"])
    #expect(abs(suggestions[0].score - 0.4 * 0.8) < 1e-9)
    #expect(abs(suggestions[1].score - 0.4 * 0.2) < 1e-9)
}

@Test func noPrev2SkipsTierOne() throws {
    let store = try storeWith(sessions: repeated(5, .afternoon, ["X", "A", "B"]))
    let first = try #require(try predict(store, prev2: nil, current: "A").first)
    #expect(first.state == "B")
    #expect(abs(first.score - 0.4) < 1e-9)  // tier 2
}

@Test func timeOfDayMatters() throws {
    let store = try storeWith(sessions: repeated(5, .morning, ["A", "B"]) + repeated(5, .evening, ["A", "C"]))
    #expect(try predict(store, prev2: nil, current: "A", bucket: .morning).first?.state == "B")
    #expect(try predict(store, prev2: nil, current: "A", bucket: .evening).first?.state == "C")
}

@Test func fallsBackToLastStateAnyTime() throws {
    // Nothing in the night, so tier 3 (after A, any time) decides.
    let store = try storeWith(sessions: repeated(5, .morning, ["A", "B"]))
    let first = try #require(try predict(store, prev2: nil, current: "A", bucket: .night).first)
    #expect(first.state == "B")
    #expect(abs(first.score - 0.16) < 1e-9)
}

// MARK: - Filtering

@Test func neverSuggestsCurrentState() throws {
    let store = try storeWith(["A", "B", "A", "B", "A", "B"])
    #expect(!(try predict(store, prev2: nil, current: "A").map(\.state).contains("A")))
}

@Test func skipsDismissed() throws {
    let store = try storeWith(sessions: repeated(5, .afternoon, ["A", "B"]) + repeated(5, .afternoon, ["A", "C"]))
    let states = try predict(store, prev2: nil, current: "A", dismissed: ["B"]).map(\.state)
    #expect(!states.contains("B"))
    #expect(states.first == "C")
}

@Test func keepsTopThree() throws {
    let store = try storeWith(sessions: ["B", "C", "D", "E", "F"].map { (.afternoon, ["A", $0]) })
    #expect(try predict(store, prev2: nil, current: "A").count == 3)
}

@Test func breaksTiesByName() throws {
    let store = try storeWith(sessions: repeated(5, .afternoon, ["A", "C"]) + repeated(5, .afternoon, ["A", "B"]))
    #expect(try predict(store, prev2: nil, current: "A").prefix(2).map(\.state) == ["B", "C"])
}

// MARK: - Confidence

@Test func unsureSuggestsNothing() throws {
    // Six apps used once each, no patterns: best plain probability is 1/6, under 0.2.
    let store = try storeWith(sessions: ["A", "B", "C", "D", "E", "F"].map { (.afternoon, [$0]) })
    #expect(try predict(store, prev2: nil, current: "Z").isEmpty)
}

@Test func confidenceUsesPlainProbabilityNotScore() throws {
    // After A: five apps, 0.2 each. Score is 0.4 × 0.2 = 0.08, but plain probability 0.2 passes.
    let store = try storeWith(sessions: ["B", "C", "D", "E", "F"].map { (.afternoon, ["A", $0]) })
    #expect(!(try predict(store, prev2: nil, current: "A").isEmpty))
}

@Test func noDataSuggestsNothing() throws {
    #expect(try predict(try EventStore(path: nil), prev2: "X", current: "A").isEmpty)
}
