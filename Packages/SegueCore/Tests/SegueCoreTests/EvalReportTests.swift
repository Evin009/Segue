import Foundation
import GRDB
import Testing
@testable import SegueCore

@Test func snapshotReadsEventsWithoutChangingOriginal() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("segue.sqlite").path

    let original = try EventStore(path: path)
    let event = CleanEvent(ts: testNoon, appID: "A", domain: nil, state: "A", durationS: 60, timeBucket: .afternoon, isWeekend: false)
    try original.append(event)

    let copy = try EventStore.snapshot(of: path)
    #expect(try copy.allEvents().map(\.state) == ["A"])

    try copy.append(CleanEvent(ts: testNoon + 60, appID: "B", domain: nil, state: "B", durationS: 60, timeBucket: .afternoon, isWeekend: false))
    #expect(try original.allEvents().map(\.state) == ["A"])
}

@Test func snapshotOfMissingFileFails() {
    #expect(throws: (any Error).self) { try EventStore.snapshot(of: "/nonexistent/segue.sqlite") }
}

@Test func reportShowsBothGuessersAndDifference() {
    var predictor = EvalResult()
    predictor.targets = 200; predictor.suggested = 180; predictor.top1Hits = 90; predictor.top3Hits = 150
    var baseline = EvalResult()
    baseline.targets = 200; baseline.suggested = 200; baseline.top1Hits = 40; baseline.top3Hits = 110

    let text = EvalReport.text(events: 500, predictor: predictor, baseline: baseline)
    #expect(text.contains("500 events, 200 switches to guess"))
    #expect(text.contains("Top-1           45.0%      20.0%    +25.0"))
    #expect(text.contains("Top-3           75.0%      55.0%    +20.0"))
    #expect(text.contains("Coverage        90.0%     100.0%    -10.0"))
}

@Test func reportWarnsWhenTooLittleData() {
    var tiny = EvalResult()
    tiny.targets = 12
    #expect(EvalReport.text(events: 20, predictor: tiny, baseline: tiny).contains("Too little data"))
}
