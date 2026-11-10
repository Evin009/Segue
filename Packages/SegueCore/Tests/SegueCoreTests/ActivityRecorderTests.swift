import Foundation
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
