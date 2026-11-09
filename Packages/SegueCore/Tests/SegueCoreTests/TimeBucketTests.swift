import Foundation
import Testing
@testable import SegueCore

private let calendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
    return calendar
}()

/// Builds a date in the test calendar. November 6, 2026 is a Friday.
private func date(day: Int = 6, hour: Int, minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute))!
}

@Test(arguments: [
    (4, 59, TimeBucket.night),
    (5, 0, .morning),
    (11, 59, .morning),
    (12, 0, .afternoon),
    (16, 59, .afternoon),
    (17, 0, .evening),
    (21, 59, .evening),
    (22, 0, .night),
    (0, 0, .night),
])
func bucketBoundaries(hour: Int, minute: Int, expected: TimeBucket) {
    #expect(TimeBucket.of(date(hour: hour, minute: minute), calendar: calendar) == expected)
}

@Test(arguments: [
    (6, false),  // Friday
    (7, true),   // Saturday
    (8, true),   // Sunday
    (9, false),  // Monday
])
func weekendDetection(day: Int, expected: Bool) {
    #expect(isWeekend(date(day: day, hour: 12), calendar: calendar) == expected)
}
