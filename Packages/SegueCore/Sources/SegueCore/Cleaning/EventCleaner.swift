import Foundation

public struct CleanerConfig: Sendable {
    /// Shorter stays are treated as passing through, not real switches.
    public var minStaySeconds: Int64
    /// Apps that are never states, such as the login screen.
    public var ignoredAppIDs: Set<String>

    public init(minStaySeconds: Int64, ignoredAppIDs: Set<String>) {
        self.minStaySeconds = minStaySeconds
        self.ignoredAppIDs = ignoredAppIDs
    }

    /// Confirm these IDs against real activity in Phase 1 Task 4.
    public static let defaultIgnoredAppIDs: Set<String> = [
        "com.apple.loginwindow",
        "com.apple.ScreenSaver.Engine",
        "com.evinbento.SegueApp",
    ]

    public static let standard = CleanerConfig(minStaySeconds: 2, ignoredAppIDs: defaultIgnoredAppIDs)
}

/// Turns raw app switches into clean events.
///
/// It holds the current state (`pending`) and the newest different state (`candidate`).
/// A candidate becomes the current state only after staying `minStaySeconds`; otherwise it was
/// a quick pass-through and its time counts toward the current state. An event is emitted only
/// once its duration is known, so stored rows never change.
public struct EventCleaner: Sendable {
    private struct Held: Sendable {
        var state: String
        var appID: String
        var ts: Int64
    }

    private let config: CleanerConfig
    private let calendar: Calendar
    private var pending: Held?
    private var candidate: Held?

    public init(config: CleanerConfig, calendar: Calendar) {
        self.config = config
        self.calendar = calendar
    }

    /// States held but not yet emitted, oldest first.
    public var heldStates: [String] {
        [pending?.state, candidate?.state].compactMap { $0 }
    }

    public mutating func ingest(_ raw: RawEvent) -> [CleanEvent] {
        guard !config.ignoredAppIDs.contains(raw.appID) else { return [] }
        let incoming = Held(state: raw.appID, appID: raw.appID, ts: raw.ts)

        guard let current = pending else {
            pending = incoming
            return []
        }

        var emitted: [CleanEvent] = []
        if let next = candidate {
            if incoming.state == next.state { return [] }
            if raw.ts - next.ts >= config.minStaySeconds {
                emitted += close(current, at: next.ts)
                pending = next
            }
            candidate = nil
        }

        if incoming.state != pending?.state {
            candidate = incoming
        }
        return emitted
    }

    /// Closes everything held, e.g. on sleep or pause.
    public mutating func flush(at ts: Int64) -> [CleanEvent] {
        guard let current = pending else { return [] }
        var emitted: [CleanEvent] = []
        if let next = candidate, ts - next.ts >= config.minStaySeconds {
            emitted += close(current, at: next.ts)
            emitted += close(next, at: ts)
        } else {
            emitted += close(current, at: ts)
        }
        pending = nil
        candidate = nil
        return emitted
    }

    private func close(_ held: Held, at end: Int64) -> [CleanEvent] {
        let duration = end - held.ts
        guard duration >= config.minStaySeconds else { return [] }
        let date = Date(timeIntervalSince1970: TimeInterval(held.ts))
        return [CleanEvent(
            ts: held.ts,
            appID: held.appID,
            state: held.state,
            durationS: duration,
            timeBucket: .of(date, calendar: calendar),
            isWeekend: isWeekend(date, calendar: calendar)
        )]
    }
}
