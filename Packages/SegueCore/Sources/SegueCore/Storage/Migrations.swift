import GRDB

enum Migrations {
    static var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1: events and transitions") { db in
            try db.execute(sql: """
                CREATE TABLE events (
                  id          INTEGER PRIMARY KEY,
                  ts          INTEGER NOT NULL,
                  app_id      TEXT    NOT NULL,
                  domain      TEXT,
                  state       TEXT    NOT NULL,
                  duration_s  INTEGER NOT NULL,
                  time_bucket TEXT    NOT NULL,
                  is_weekend  INTEGER NOT NULL
                );
                CREATE INDEX idx_events_ts ON events(ts);

                CREATE TABLE transitions (
                  prev2       TEXT NOT NULL,
                  prev1       TEXT NOT NULL,
                  next        TEXT NOT NULL,
                  time_bucket TEXT NOT NULL,
                  weight      REAL NOT NULL,
                  PRIMARY KEY (prev2, prev1, next, time_bucket)
                );
                """)
        }

        migrator.registerMigration("v2: feedback") { db in
            try db.execute(sql: """
                CREATE TABLE feedback (
                  prev1             TEXT    NOT NULL,
                  next              TEXT    NOT NULL,
                  accepts           INTEGER NOT NULL DEFAULT 0,
                  dismisses         INTEGER NOT NULL DEFAULT 0,
                  last_dismissed_at INTEGER,
                  PRIMARY KEY (prev1, next)
                );
                """)
        }

        return migrator
    }
}
