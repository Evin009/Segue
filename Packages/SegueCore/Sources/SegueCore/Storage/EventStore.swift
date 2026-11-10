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
