import Foundation

/// Part of the day an event happens in, using the Mac's local time.
public enum TimeBucket: String, CaseIterable, Sendable {
    case morning    // 5:00 to 11:59
    case afternoon  // 12:00 to 16:59
    case evening    // 17:00 to 21:59
    case night      // 22:00 to 4:59

    public static func of(_ date: Date, calendar: Calendar) -> TimeBucket {
        switch calendar.component(.hour, from: date) {
        case 5..<12: .morning
        case 12..<17: .afternoon
        case 17..<22: .evening
        default: .night
        }
    }
}

/// Whether the date falls on a weekend in the given calendar.
public func isWeekend(_ date: Date, calendar: Calendar) -> Bool {
    calendar.isDateInWeekend(date)
}
