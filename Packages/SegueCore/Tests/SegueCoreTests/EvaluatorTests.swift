import Foundation
import Testing
@testable import SegueCore

/// One session of visits, 60 s each, starting at `start`.
private func session(_ states: [String], start: Int64 = testNoon) -> [CleanEvent] {
    states.enumerated().map { i, state in
        CleanEvent(
            ts: start + Int64(i) * 60, appID: state, domain: nil, state: state,
            durationS: 60, timeBucket: .afternoon, isWeekend: false
        )
    }
}

private func always(_ states: [String]) -> Evaluator.Predict {
    { _, _, _, _ in states.map { Suggestion(state: $0, score: 1) } }
}

@Test func countsTopOneAndTopThreeHits() throws {
    // Targets: B (after A), C (after B). Guess is always B, C, D.
    let result = try Evaluator.evaluate(session(["A", "B", "C"]), predict: always(["B", "C", "D"]))
    #expect(result.targets == 2)
    #expect(result.top1Hits == 1)  // B
    #expect(result.top3Hits == 2)  // B and C
    #expect(result.top1Accuracy == 0.5)
    #expect(result.top3Accuracy == 1.0)
}

@Test func silenceCountsAsMiss() throws {
    let result = try Evaluator.evaluate(session(["A", "B", "C"]), predict: always([]))
    #expect(result.targets == 2)
    #expect(result.suggested == 0)
    #expect(result.coverage == 0)
    #expect(result.top3Hits == 0)
}

@Test func onlyTopThreeCount() throws {
    let result = try Evaluator.evaluate(session(["A", "E"]), predict: always(["B", "C", "D", "E"]))
    #expect(result.top3Hits == 0)
}

@Test func sessionStartsAreNotTargets() throws {
    // Two hours apart: nothing to predict from.
    let events = session(["A"]) + session(["B"], start: testNoon + 7200)
    #expect(try Evaluator.evaluate(events, predict: always(["B"])).targets == 0)
}

@Test func continuingSameVisitIsNotTarget() throws {
    // A, short pause, A again: still one visit.
    #expect(try Evaluator.evaluate(session(["A", "A"]), predict: always(["A"])).targets == 0)
}

@Test func predictsOnlyFromEarlierData() throws {
    var seen: [[String]] = []
    _ = try Evaluator.evaluate(session(["A", "B", "C"])) { store, _, _, _ in
        seen.append(try store.allEvents().map(\.state))
        return []
    }
    #expect(seen == [["A"], ["A", "B"]])
}

@Test func passesLastTwoStatesAndTimeOfDay() throws {
    var seen: [String] = []
    _ = try Evaluator.evaluate(session(["A", "B", "C"])) { _, prev2, current, bucket in
        seen.append("\(prev2 ?? "-") \(current) \(bucket.rawValue)")
        return []
    }
    #expect(seen == ["- A afternoon", "A B afternoon"])
}

@Test func noTargetsGivesZeroNotNaN() throws {
    let result = try Evaluator.evaluate([], predict: always(["A"]))
    #expect(result.top1Accuracy == 0)
    #expect(result.top3Accuracy == 0)
    #expect(result.coverage == 0)
}

@Test func predictorBeatsBaselineOnRoutine() throws {
    // Same routine 10 times: X → A → B → C. Baseline can't tell what follows A; predictor can.
    let events = (0..<10).flatMap { session(["X", "A", "B", "C"], start: testNoon + Int64($0) * 7200) }
    let predictor = try Evaluator.evaluate(events, predict: Evaluator.predictor)
    let baseline = try Evaluator.evaluate(events, predict: Evaluator.baseline)
    #expect(predictor.top1Accuracy > baseline.top1Accuracy)
}
