import GRDB
import Testing

@Test func grdbOpensInMemoryDatabase() throws {
    let database = try DatabaseQueue()

    let value = try database.read { db in
        try Int.fetchOne(db, sql: "SELECT 1")
    }

    #expect(value == 1)
}
