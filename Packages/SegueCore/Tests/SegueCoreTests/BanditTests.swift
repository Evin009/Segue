import Foundation
import Testing
@testable import SegueCore

/// After A: B 6 times, C 4 times (tier 2, afternoon).
private func storeBC() throws -> EventStore {
    try storeWith(sessions: repeated(6, .afternoon, ["A", "B"]) + repeated(4, .afternoon, ["A", "C"]))
}

@Test func trustIsNeutralWithNoFeedback() {
    #expect(Predictor.trust(Feedback(accepts: 0, dismisses: 0)) == 1.0)
}

@Test func trustFollowsBetaEstimate() {
    // (accepts + 1) / (accepts + dismisses + 2), scaled so no feedback = 1.
    #expect(abs(Predictor.trust(Feedback(accepts: 1, dismisses: 4)) - 2.0 * 2 / 7) < 1e-9)
    #expect(abs(Predictor.trust(Feedback(accepts: 3, dismisses: 0)) - 2.0 * 4 / 5) < 1e-9)
}

@Test func dismissingMovesSuggestionDown() throws {
    let store = try storeBC()
    #expect(try Predictor(store: store).predict(prev2: nil, current: "A", timeBucket: .afternoon).first?.state == "B")

    let feedback = ["B": Feedback(accepts: 0, dismisses: 5)]
    let ranked = try Predictor(store: store).predict(prev2: nil, current: "A", timeBucket: .afternoon, feedback: feedback)
    #expect(ranked.map(\.state).prefix(2) == ["C", "B"])
}

@Test func acceptingMovesSuggestionUp() throws {
    let store = try storeBC()
    let feedback = ["C": Feedback(accepts: 4, dismisses: 0)]
    let ranked = try Predictor(store: store).predict(prev2: nil, current: "A", timeBucket: .afternoon, feedback: feedback)
    #expect(ranked.first?.state == "C")
}

@Test func feedbackChangesScoreNotConfidence() throws {
    // B is 100% likely after A. Heavy dismissing lowers its score but it still passes the 20% check.
    let store = try storeWith(sessions: repeated(5, .afternoon, ["A", "B"]))
    let feedback = ["B": Feedback(accepts: 0, dismisses: 20)]
    let ranked = try Predictor(store: store).predict(prev2: nil, current: "A", timeBucket: .afternoon, feedback: feedback)
    #expect(ranked.first?.state == "B")
}

@Test func suggestReadsFeedbackAndDismissalsFromStore() throws {
    let store = try storeBC()
    let predictor = Predictor(store: store)

    try store.recordFeedback(after: "A", suggested: "B", accepted: false, at: 100)
    let hidden = try predictor.suggest(prev2: nil, current: "A", timeBucket: .afternoon, at: 200)
    #expect(!hidden.map(\.state).contains("B"))

    // Five hours later B is back, but ranked below C because of the dismissals.
    for t in [110, 120, 130] as [Int64] {
        try store.recordFeedback(after: "A", suggested: "B", accepted: false, at: t)
    }
    let later = try predictor.suggest(prev2: nil, current: "A", timeBucket: .afternoon, at: 130 + 5 * 3600)
    #expect(later.map(\.state).prefix(2) == ["C", "B"])
}
