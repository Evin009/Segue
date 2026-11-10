import Foundation
import GRDB
import Testing
@testable import SegueCore

private func makeRecorder() throws -> (ActivityRecorder, EventStore) {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    let store = try EventStore(path: nil)
    let recorder = ActivityRecorder(cleaner: EventCleaner(config: .standard, calendar: calendar), store: store)
    return (recorder, store)
}

@Test func switchesAreSaved() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.appActivated("A", at: 0)
    try recorder.appActivated("B", at: 10)
    try recorder.appActivated("C", at: 20)
    #expect(try store.allEvents().map(\.state) == ["A"])
}

@Test func interruptSavesWhatIsHeld() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.appActivated("A", at: 0)
    try recorder.interrupt(at: 50)
    let events = try store.allEvents()
    #expect(events.map(\.state) == ["A"])
    #expect(events.map(\.durationS) == [50])
}

@Test func pauseSavesHeldAndStopsRecording() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.appActivated("A", at: 0)
    try recorder.pause(at: 10)
    try recorder.appActivated("B", at: 20)
    try recorder.appActivated("C", at: 40)
    try recorder.interrupt(at: 60)
    #expect(recorder.isPaused)
    #expect(try store.allEvents().map(\.state) == ["A"])
}

@Test func resumeStartsFromFrontApp() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.pause(at: 0)
    try recorder.resume(frontAppID: "B", at: 100)
    try recorder.appActivated("C", at: 110)
    try recorder.interrupt(at: 120)
    #expect(!recorder.isPaused)
    #expect(try store.allEvents().map(\.state) == ["B", "C"])
}

@Test func resumeWithNoFrontAppRecordsNothing() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.pause(at: 0)
    try recorder.resume(frontAppID: nil, at: 100)
    try recorder.interrupt(at: 200)
    #expect(try store.allEvents().isEmpty)
}

// MARK: - Screen lock and user switching

@Test func lockSavesHeldAndIgnoresEverythingUntilUnlock() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.appActivated("A", at: 0)
    try recorder.lock(at: 10)
    try recorder.wake(frontAppID: "A", at: 20)  // display wakes at the lock screen
    try recorder.appActivated("B", at: 30)
    try recorder.unlock(frontAppID: "C", at: 100)
    try recorder.interrupt(at: 110)

    let events = try store.allEvents()
    #expect(events.map(\.state) == ["A", "C"])
    #expect(events.map(\.durationS) == [10, 10])
}

@Test func wakeWhenUnlockedRecordsFrontApp() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.interrupt(at: 0)
    try recorder.wake(frontAppID: "A", at: 10)
    try recorder.interrupt(at: 20)
    #expect(try store.allEvents().map(\.state) == ["A"])
}

@Test func unlockWhilePausedStaysPaused() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.pause(at: 0)
    try recorder.lock(at: 10)
    try recorder.unlock(frontAppID: "A", at: 20)
    try recorder.interrupt(at: 40)
    #expect(recorder.isPaused)
    #expect(try store.allEvents().isEmpty)
}

@Test func resumeWhileLockedWaitsForUnlock() throws {
    var (recorder, store) = try makeRecorder()
    try recorder.pause(at: 0)
    try recorder.lock(at: 10)
    try recorder.resume(frontAppID: "A", at: 20)
    try recorder.unlock(frontAppID: "B", at: 30)
    try recorder.interrupt(at: 40)
    #expect(try store.allEvents().map(\.state) == ["B"])
}

// MARK: - Save failures

@Test func pauseSticksWhenSaveFails() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("segue.sqlite").path

    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    var recorder = ActivityRecorder(
        cleaner: EventCleaner(config: .standard, calendar: calendar),
        store: try EventStore(path: path)
    )
    try recorder.appActivated("A", at: 0)

    // Break the database from a second connection so the next save throws.
    try DatabaseQueue(path: path).write { try $0.execute(sql: "DROP TABLE events") }

    #expect(throws: (any Error).self) { try recorder.pause(at: 10) }
    #expect(recorder.isPaused)
}

@Test func savedCountGrowsOnlyWhenEventsAreSaved() throws {
    var (recorder, _) = try makeRecorder()
    #expect(recorder.savedCount == 0)
    try recorder.appActivated("A", at: 0)
    try recorder.appActivated("B", at: 10)
    #expect(recorder.savedCount == 0)  // nothing finished yet
    try recorder.pause(at: 20)
    #expect(recorder.savedCount == 2)  // A and B
    try recorder.appActivated("C", at: 30)  // ignored while paused
    #expect(recorder.savedCount == 2)
}
