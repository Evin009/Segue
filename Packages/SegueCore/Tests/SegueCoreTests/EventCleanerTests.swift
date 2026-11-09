import Foundation
import Testing
@testable import SegueCore

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

private func makeCleaner() -> EventCleaner {
    EventCleaner(config: .standard, calendar: utc)
}

/// Feeds `(app, second)` pairs to the cleaner and returns `(state, duration)` for everything emitted.
private func run(_ cleaner: inout EventCleaner, _ switches: [(String, Int64)]) -> [(String, Int64)] {
    switches
        .flatMap { app, ts in cleaner.ingest(RawEvent(ts: ts, appID: app)) }
        .map { ($0.state, $0.durationS) }
}

private func flush(_ cleaner: inout EventCleaner, at ts: Int64) -> [(String, Int64)] {
    cleaner.flush(at: ts).map { ($0.state, $0.durationS) }
}

@Test func stableSwitchEmits() {
    var cleaner = makeCleaner()
    let out = run(&cleaner, [("A", 0), ("B", 10), ("C", 20), ("D", 30)])
    #expect(out.map(\.0) == ["A", "B"])
    #expect(out.map(\.1) == [10, 10])
    #expect(cleaner.heldStates == ["C", "D"])
}

@Test func flickerIsAbsorbed() {
    var cleaner = makeCleaner()
    let out = run(&cleaner, [("A", 0), ("B", 10), ("A", 11), ("C", 30), ("D", 40)])
    #expect(out.map(\.0) == ["A"])
    #expect(out.map(\.1) == [30])
}

@Test func duplicatesMerge() {
    var cleaner = makeCleaner()
    let out = run(&cleaner, [("A", 0), ("A", 5), ("B", 10), ("C", 20)])
    #expect(out.map(\.0) == ["A"])
    #expect(out.map(\.1) == [10])
}

@Test func repeatedNewAppKeepsItsStart() {
    var cleaner = makeCleaner()
    let out = run(&cleaner, [("A", 0), ("B", 10), ("B", 11), ("C", 20)])
    #expect(out.map(\.0) == ["A"])
    #expect(flush(&cleaner, at: 30).map(\.1) == [10, 10])  // B from 10, C from 20
}

@Test func ignoredAppIsNotAState() {
    var cleaner = makeCleaner()
    let out = run(&cleaner, [("A", 0), ("com.apple.loginwindow", 10), ("B", 20), ("C", 30)])
    #expect(out.map(\.0) == ["A"])
    #expect(out.map(\.1) == [20])
    #expect(!cleaner.heldStates.contains("com.apple.loginwindow"))
}

@Test func flushClosesPending() {
    var cleaner = makeCleaner()
    _ = run(&cleaner, [("A", 0)])
    let first = flush(&cleaner, at: 50)
    #expect(first.map(\.0) == ["A"])
    #expect(first.map(\.1) == [50])
    #expect(flush(&cleaner, at: 60).isEmpty)
    #expect(cleaner.heldStates.isEmpty)
}

@Test func flushEmitsStableCandidate() {
    var cleaner = makeCleaner()
    _ = run(&cleaner, [("A", 0), ("B", 10)])
    let out = flush(&cleaner, at: 20)
    #expect(out.map(\.0) == ["A", "B"])
    #expect(out.map(\.1) == [10, 10])
}

@Test func flushDropsFlickerCandidate() {
    var cleaner = makeCleaner()
    _ = run(&cleaner, [("A", 0), ("B", 10)])
    let out = flush(&cleaner, at: 11)
    #expect(out.map(\.0) == ["A"])
    #expect(out.map(\.1) == [11])
}

@Test func flushDropsShortPending() {
    var cleaner = makeCleaner()
    _ = run(&cleaner, [("A", 0)])
    #expect(flush(&cleaner, at: 1).isEmpty)
}

@Test func shortFirstStateIsDropped() {
    var cleaner = makeCleaner()
    let out = run(&cleaner, [("A", 0), ("B", 1), ("C", 20)])
    #expect(out.isEmpty)
    #expect(cleaner.heldStates == ["B", "C"])
}

@Test func heldStatesTrackLiveApp() {
    var cleaner = makeCleaner()
    _ = run(&cleaner, [("A", 0), ("B", 10)])
    #expect(cleaner.heldStates == ["A", "B"])
}

@Test func emittedEventHasTimeContext() throws {
    var cleaner = makeCleaner()
    // Saturday, November 7, 2026, 09:00 UTC.
    let start = Int64(utc.date(from: DateComponents(year: 2026, month: 11, day: 7, hour: 9))!.timeIntervalSince1970)
    let out = [RawEvent(ts: start, appID: "A"), RawEvent(ts: start + 10, appID: "B"), RawEvent(ts: start + 20, appID: "C")]
        .flatMap { cleaner.ingest($0) }
    let event = try #require(out.first)
    #expect(event == CleanEvent(ts: start, appID: "A", state: "A", durationS: 10, timeBucket: .morning, isWeekend: true))
}
