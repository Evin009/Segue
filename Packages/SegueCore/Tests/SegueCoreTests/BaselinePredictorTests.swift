import Foundation
import Testing
@testable import SegueCore

/// Saves visits one after another, each `gap` seconds long, starting at noon UTC on 2026-11-10.
private func storeWith(_ states: [String], gap: Int64 = 60) throws -> EventStore {
    let store = try EventStore(path: nil)
    let noon: Int64 = 1_794_312_000
    for (i, state) in states.enumerated() {
        try store.append(CleanEvent(
            ts: noon + Int64(i) * gap, appID: state, domain: nil, state: state,
            durationS: gap, timeBucket: .afternoon, isWeekend: false
        ))
    }
    return store
}

@Test func baselineSuggestsMostUsedFirst() throws {
    let store = try storeWith(["A", "B", "A", "C", "A", "B", "D"])
    let suggestions = try BaselinePredictor(store: store).predict(current: "D")
    #expect(suggestions.map(\.state) == ["A", "B", "C"])
}

@Test func baselineScoreIsShareOfAllVisits() throws {
    let store = try storeWith(["A", "B", "A", "C"])
    let suggestions = try BaselinePredictor(store: store).predict(current: "C")
    #expect(suggestions.map(\.score) == [0.5, 0.25])
}

@Test func baselineSkipsCurrentState() throws {
    let store = try storeWith(["A", "A2", "A", "B"])
    let suggestions = try BaselinePredictor(store: store).predict(current: "A")
    #expect(!suggestions.map(\.state).contains("A"))
}

@Test func baselineBreaksTiesByName() throws {
    let store = try storeWith(["C", "B", "A"])
    let suggestions = try BaselinePredictor(store: store).predict(current: "Z")
    #expect(suggestions.map(\.state) == ["A", "B", "C"])
}

@Test func baselineKeepsTopThree() throws {
    let store = try storeWith(["A", "B", "C", "D", "E"])
    #expect(try BaselinePredictor(store: store).predict(current: "Z").count == 3)
}

@Test func baselineWithNoDataSuggestsNothing() throws {
    let store = try EventStore(path: nil)
    #expect(try BaselinePredictor(store: store).predict(current: "A").isEmpty)
}
