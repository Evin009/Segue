import GRDB

public enum EventStoreError: Error {
    case unknownTimeBucket(String)
}

/// Saves clean events and keeps the "what came next" counts up to date.
public final class EventStore: Sendable {
    public static let defaultSessionGapSeconds: Int64 = 1800

    private let database: DatabaseQueue
    private let sessionGapSeconds: Int64

    /// - Parameter path: database file, or `nil` for an in-memory database.
    public init(path: String?, sessionGapSeconds: Int64 = EventStore.defaultSessionGapSeconds) throws {
        database = try path.map { try DatabaseQueue(path: $0) } ?? DatabaseQueue()
        self.sessionGapSeconds = sessionGapSeconds
        try Migrations.migrator.migrate(database)
    }

    private init(database: DatabaseQueue, sessionGapSeconds: Int64) throws {
        self.database = database
        self.sessionGapSeconds = sessionGapSeconds
        try Migrations.migrator.migrate(database)
    }

    /// An in-memory copy of the database at `path`. The file is opened read-only and never changed,
    /// so this is safe while Segue is running.
    public static func snapshot(
        of path: String, sessionGapSeconds: Int64 = EventStore.defaultSessionGapSeconds
    ) throws -> EventStore {
        var config = Configuration()
        config.readonly = true
        let source = try DatabaseQueue(path: path, configuration: config)
        let copy = try DatabaseQueue()
        try source.backup(to: copy)
        return try EventStore(database: copy, sessionGapSeconds: sessionGapSeconds)
    }

    /// Saves the event and adds to its counts in one transaction, so both happen or neither does.
    public func append(_ event: CleanEvent) throws {
        try database.write { db in
            // Extra rows so a visit split by several pauses still collapses into one.
            let previous = try Self.recentEvents(db, limit: 10)
            try db.execute(
                sql: """
                    INSERT INTO events (ts, app_id, domain, state, duration_s, time_bucket, is_weekend)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                arguments: [event.ts, event.appID, event.domain, event.state, event.durationS,
                            event.timeBucket.rawValue, event.isWeekend]
            )
            for key in transitionKeys(for: event, previous: previous, sessionGapSeconds: sessionGapSeconds) {
                try db.execute(
                    sql: """
                        INSERT INTO transitions (prev2, prev1, next, time_bucket, weight)
                        VALUES (?, ?, ?, ?, 1)
                        ON CONFLICT (prev2, prev1, next, time_bucket) DO UPDATE SET weight = weight + 1
                        """,
                    arguments: [key.prev2, key.prev1, key.next, key.timeBucket]
                )
            }
        }
    }

    /// All events, oldest first.
    public func allEvents() throws -> [CleanEvent] {
        try database.read { db in
            try Row.fetchAll(db, sql: "SELECT * FROM events ORDER BY ts, id").map(Self.event)
        }
    }

    /// The latest `limit` events, oldest first.
    public func recentEvents(limit: Int) throws -> [CleanEvent] {
        try database.read { db in try Self.recentEvents(db, limit: limit) }
    }

    /// Counts for each next state after the given context.
    public func weights(prev2: String, prev1: String, timeBucket: String) throws -> [String: Double] {
        try database.read { db in
            let rows = try Row.fetchAll(
                db,
                sql: "SELECT next, weight FROM transitions WHERE prev2 = ? AND prev1 = ? AND time_bucket = ?",
                arguments: [prev2, prev1, timeBucket]
            )
            return Dictionary(uniqueKeysWithValues: rows.map { ($0["next"] as String, $0["weight"] as Double) })
        }
    }

    // MARK: - Feedback

    /// How long a dismissed suggestion stays hidden in the same context.
    public static let dismissWindowSeconds: Int64 = 4 * 3600

    /// Saves that `suggested` was accepted or dismissed while you were in `after`.
    /// Accepting also ends any recent dismissal, so it can show again right away.
    public func recordFeedback(after prev1: String, suggested next: String, accepted: Bool, at ts: Int64) throws {
        try database.write { db in
            try db.execute(
                sql: """
                    INSERT INTO feedback (prev1, next, accepts, dismisses, last_dismissed_at)
                    VALUES (?, ?, ?, ?, ?)
                    ON CONFLICT (prev1, next) DO UPDATE SET
                      accepts = accepts + excluded.accepts,
                      dismisses = dismisses + excluded.dismisses,
                      last_dismissed_at = excluded.last_dismissed_at
                    """,
                arguments: [prev1, next, accepted ? 1 : 0, accepted ? 0 : 1, accepted ? nil : ts]
            )
        }
    }

    /// Accept and dismiss counts for each suggestion made while in `prev1`.
    public func feedback(after prev1: String) throws -> [String: Feedback] {
        try database.read { db in
            let rows = try Row.fetchAll(
                db, sql: "SELECT next, accepts, dismisses FROM feedback WHERE prev1 = ?", arguments: [prev1]
            )
            return Dictionary(uniqueKeysWithValues: rows.map {
                ($0["next"] as String, Feedback(accepts: $0["accepts"], dismisses: $0["dismisses"]))
            })
        }
    }

    /// Suggestions dismissed while in `prev1` within the last 4 hours before `ts`.
    public func recentlyDismissed(after prev1: String, at ts: Int64) throws -> Set<String> {
        try database.read { db in
            Set(try String.fetchAll(
                db,
                sql: "SELECT next FROM feedback WHERE prev1 = ? AND last_dismissed_at > ?",
                arguments: [prev1, ts - Self.dismissWindowSeconds]
            ))
        }
    }

    private static func recentEvents(_ db: Database, limit: Int) throws -> [CleanEvent] {
        try Row.fetchAll(db, sql: "SELECT * FROM events ORDER BY ts DESC, id DESC LIMIT ?", arguments: [limit])
            .map(event)
            .reversed()
    }

    private static func event(from row: Row) throws -> CleanEvent {
        let bucketName: String = row["time_bucket"]
        guard let bucket = TimeBucket(rawValue: bucketName) else {
            throw EventStoreError.unknownTimeBucket(bucketName)
        }
        return CleanEvent(
            ts: row["ts"],
            appID: row["app_id"],
            domain: row["domain"],
            state: row["state"],
            durationS: row["duration_s"],
            timeBucket: bucket,
            isWeekend: row["is_weekend"]
        )
    }
}
