import Foundation
import Testing
@testable import SegueCore

private func saved(_ states: [String], endingAt end: Int64) -> [CleanEvent] {
    let start = end - Int64(states.count) * 60
    return states.enumerated().map { i, state in
        CleanEvent(ts: start + Int64(i) * 60, appID: state, domain: nil, state: state,
                   durationS: 60, timeBucket: .afternoon, isWeekend: false)
    }
}

@Test func contextUsesVisitBeforeCurrent() {
    let context = PredictionContext(recent: saved(["A", "B"], endingAt: 1000), held: ["C"], heldSince: 1000, current: "C", now: 1010)
    #expect(context == PredictionContext(prev2: "B", current: "C"))
}

@Test func contextIncludesHeldStatesNotYetSaved() {
    // B is held in the cleaner, not saved yet; C is the front app.
    let context = PredictionContext(recent: saved(["A"], endingAt: 1000), held: ["B"], heldSince: 1000, current: "C", now: 1010)
    #expect(context.prev2 == "B")
}

@Test func contextCollapsesRepeats() {
    let context = PredictionContext(recent: saved(["A", "B", "B"], endingAt: 1000), held: ["B"], heldSince: 1000, current: "B", now: 1010)
    #expect(context == PredictionContext(prev2: "A", current: "B"))
}

@Test func contextIgnoresOldSession() {
    // Last saved visit ended 2 hours ago: not connected.
    let context = PredictionContext(recent: saved(["A"], endingAt: 1000), held: [], current: "C", now: 1000 + 7200)
    #expect(context.prev2 == nil)
}

@Test func contextWithNoHistory() {
    #expect(PredictionContext(recent: [], held: [], current: "A", now: 0) == PredictionContext(prev2: nil, current: "A"))
}

@Test func contextIgnoresOldSessionBeforeHeldVisit() {
    // Saved A ended at 1000; held B started 2 hours later. A is a different session.
    let context = PredictionContext(recent: saved(["A"], endingAt: 1000), held: ["B"], heldSince: 1000 + 7200, current: "C", now: 1000 + 7300)
    #expect(context == PredictionContext(prev2: "B", current: "C"))

    let alone = PredictionContext(recent: saved(["A"], endingAt: 1000), held: ["B"], heldSince: 1000 + 7200, current: "B", now: 1000 + 7300)
    #expect(alone.prev2 == nil)
}

@Test func cleanerReportsWhenHeldVisitsStarted() {
    var cleaner = EventCleaner(config: .standard, calendar: Calendar(identifier: .gregorian))
    #expect(cleaner.heldSince == nil)
    _ = cleaner.ingest(RawEvent(ts: 100, appID: "A"))
    _ = cleaner.ingest(RawEvent(ts: 150, appID: "B"))
    #expect(cleaner.heldSince == 100)
}
