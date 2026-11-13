import Foundation
import Testing
@testable import SegueCore

@Test func feedbackStartsEmpty() throws {
    let store = try EventStore(path: nil)
    #expect(try store.feedback(after: "Chrome").isEmpty)
}

@Test func acceptsAndDismissesAreCountedPerContext() throws {
    let store = try EventStore(path: nil)
    try store.recordFeedback(after: "Chrome", suggested: "Mail", accepted: true, at: 0)
    try store.recordFeedback(after: "Chrome", suggested: "Mail", accepted: false, at: 10)
    try store.recordFeedback(after: "Chrome", suggested: "Mail", accepted: false, at: 20)
    try store.recordFeedback(after: "Slack", suggested: "Mail", accepted: true, at: 30)

    #expect(try store.feedback(after: "Chrome") == ["Mail": Feedback(accepts: 1, dismisses: 2)])
    #expect(try store.feedback(after: "Slack") == ["Mail": Feedback(accepts: 1, dismisses: 0)])
}

@Test func dismissedHiddenForFourHoursInSameContext() throws {
    let store = try EventStore(path: nil)
    try store.recordFeedback(after: "Chrome", suggested: "Mail", accepted: false, at: 1000)

    let fourHours: Int64 = 4 * 3600
    #expect(try store.recentlyDismissed(after: "Chrome", at: 1000 + fourHours - 1) == ["Mail"])
    #expect(try store.recentlyDismissed(after: "Chrome", at: 1000 + fourHours).isEmpty)
    #expect(try store.recentlyDismissed(after: "Slack", at: 1001).isEmpty)
}

@Test func acceptingClearsRecentDismissal() throws {
    let store = try EventStore(path: nil)
    try store.recordFeedback(after: "Chrome", suggested: "Mail", accepted: false, at: 0)
    try store.recordFeedback(after: "Chrome", suggested: "Mail", accepted: true, at: 60)
    #expect(try store.recentlyDismissed(after: "Chrome", at: 120).isEmpty)
}

@Test func feedbackSurvivesReopen() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("segue.sqlite").path

    try EventStore(path: path).recordFeedback(after: "Chrome", suggested: "Mail", accepted: true, at: 0)
    #expect(try EventStore(path: path).feedback(after: "Chrome") == ["Mail": Feedback(accepts: 1, dismisses: 0)])
}
