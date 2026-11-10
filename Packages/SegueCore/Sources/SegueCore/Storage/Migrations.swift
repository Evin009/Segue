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

        return migrator
    }
}
