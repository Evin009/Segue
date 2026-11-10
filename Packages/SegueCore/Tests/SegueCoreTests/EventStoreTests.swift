import Foundation
import Testing
@testable import SegueCore

private let gap: Int64 = 1800

private func event(_ state: String, at ts: Int64, for duration: Int64 = 10, _ bucket: TimeBucket = .morning) -> CleanEvent {
    CleanEvent(ts: ts, appID: state, state: state, durationS: duration, timeBucket: bucket, isWeekend: false)
}

private func key(_ prev2: String, _ prev1: String, _ next: String, _ bucket: String) -> TransitionKey {
    TransitionKey(prev2: prev2, prev1: prev1, next: next, timeBucket: bucket)
}

// MARK: - Which counts each event adds to

@Test func firstEventWritesOverallOnly() {
    let keys = transitionKeys(for: event("A", at: 0), previous: [], sessionGapSeconds: gap)
    #expect(keys == [key("", "", "A", "any")])
}

@Test func secondEventWritesThreeTiers() {
    let keys = transitionKeys(for: event("B", at: 10), previous: [event("A", at: 0)], sessionGapSeconds: gap)
    #expect(keys == [
        key("", "A", "B", "morning"),
        key("", "A", "B", "any"),
        key("", "", "B", "any"),
    ])
}

@Test func thirdEventWritesFourTiersWithNextEventsBucket() {
    let previous = [event("A", at: 0, .morning), event("B", at: 10, .morning)]
    let keys = transitionKeys(for: event("C", at: 20, .afternoon), previous: previous, sessionGapSeconds: gap)
    #expect(keys == [
        key("A", "B", "C", "afternoon"),
        key("", "B", "C", "afternoon"),
        key("", "B", "C", "any"),
        key("", "", "C", "any"),
    ])
}

@Test func sessionGapClearsContext() {
    // A ends at 10. B starts an hour later.
    let keys = transitionKeys(for: event("B", at: 3610), previous: [event("A", at: 0)], sessionGapSeconds: gap)
    #expect(keys == [key("", "", "B", "any")])
}

@Test func gapAtLimitKeepsContext() {
    // A ends at 10. B starts exactly 1800 seconds later.
    let keys = transitionKeys(for: event("B", at: 1810), previous: [event("A", at: 0)], sessionGapSeconds: gap)
    #expect(keys.count == 3)
}

@Test func gapBetweenPrev2AndPrev1DropsPrev2() {
    let previous = [event("A", at: 0), event("B", at: 5000)]
    let keys = transitionKeys(for: event("C", at: 5010), previous: previous, sessionGapSeconds: gap)
    #expect(keys == [
        key("", "B", "C", "morning"),
        key("", "B", "C", "any"),
        key("", "", "C", "any"),
    ])
}

@Test func sameAppAfterPauseAddsNoCounts() {
    // A ends at 10, pause, A again at 14.
    let keys = transitionKeys(for: event("A", at: 14), previous: [event("A", at: 0)], sessionGapSeconds: gap)
    #expect(keys.isEmpty)
}

@Test func sameAppAfterPauseIsOneVisitForContext() {
    // X, then A split in two by a short pause, then B.
    let previous = [event("X", at: 0), event("A", at: 10), event("A", at: 24)]
    let keys = transitionKeys(for: event("B", at: 34), previous: previous, sessionGapSeconds: gap)
    #expect(keys.first == key("X", "A", "B", "morning"))
    #expect(keys.count == 4)
}

@Test func sameAppAfterLongGapIsNewVisit() {
    let keys = transitionKeys(for: event("A", at: 5000), previous: [event("A", at: 0)], sessionGapSeconds: gap)
    #expect(keys == [key("", "", "A", "any")])
}

// MARK: - Store

@Test func storeTreatsPauseSplitAsOneVisit() throws {
    let store = try EventStore(path: nil)
    try store.append(event("X", at: 0))
    try store.append(event("A", at: 10))
    try store.append(event("A", at: 24))
    try store.append(event("B", at: 34))

    #expect(try store.weights(prev2: "", prev1: "A", timeBucket: "any") == ["B": 1])
    #expect(try store.weights(prev2: "X", prev1: "A", timeBucket: "morning") == ["B": 1])
    #expect(try store.weights(prev2: "", prev1: "", timeBucket: "any") == ["X": 1, "A": 1, "B": 1])
}

@Test func appendSavesEventAndCounts() throws {
    let store = try EventStore(path: nil)
    let events = [event("A", at: 0), event("B", at: 10), event("C", at: 20)]
    for e in events { try store.append(e) }

    #expect(try store.weights(prev2: "A", prev1: "B", timeBucket: "morning") == ["C": 1])
    #expect(try store.allEvents() == events)
}

@Test func countsAddUp() throws {
    let store = try EventStore(path: nil)
    for (i, state) in ["A", "B", "A", "B"].enumerated() {
        try store.append(event(state, at: Int64(i) * 10))
    }
    #expect(try store.weights(prev2: "", prev1: "A", timeBucket: "any") == ["B": 2])
    #expect(try store.weights(prev2: "", prev1: "", timeBucket: "any") == ["A": 2, "B": 2])
}

@Test func storeAppliesSessionGap() throws {
    let store = try EventStore(path: nil)
    try store.append(event("A", at: 0))
    try store.append(event("B", at: 3610))
    #expect(try store.weights(prev2: "", prev1: "A", timeBucket: "any").isEmpty)
}

@Test func unknownContextIsEmpty() throws {
    let store = try EventStore(path: nil)
    #expect(try store.weights(prev2: "", prev1: "X", timeBucket: "any").isEmpty)
}

@Test func recentEventsAreOldestFirst() throws {
    let store = try EventStore(path: nil)
    for (i, state) in ["A", "B", "C"].enumerated() {
        try store.append(event(state, at: Int64(i) * 10))
    }
    #expect(try store.recentEvents(limit: 2).map(\.state) == ["B", "C"])
}

@Test func reopenKeepsData() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("segue.sqlite").path

    do {
        let store = try EventStore(path: path)
        try store.append(event("A", at: 0))
        try store.append(event("B", at: 10))
    }
    let reopened = try EventStore(path: path)
    try reopened.append(event("C", at: 20))

    #expect(try reopened.allEvents().map(\.state) == ["A", "B", "C"])
    #expect(try reopened.weights(prev2: "A", prev1: "B", timeBucket: "morning") == ["C": 1])
}
