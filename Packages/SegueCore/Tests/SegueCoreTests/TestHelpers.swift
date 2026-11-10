import Foundation
@testable import SegueCore

/// Noon UTC, 2026-11-10.
let testNoon: Int64 = 1_794_312_000

/// Saves visits one after another in one session, each `gap` seconds long.
func storeWith(_ states: [String], gap: Int64 = 60) throws -> EventStore {
    try storeWith(sessions: [(.afternoon, states)], gap: gap)
}

/// Saves each session's visits one after another. Sessions are 2 hours apart, so they don't connect.
func storeWith(sessions: [(TimeBucket, [String])], gap: Int64 = 60) throws -> EventStore {
    let store = try EventStore(path: nil)
    for (s, (bucket, states)) in sessions.enumerated() {
        let start = testNoon + Int64(s) * 7200
        for (i, state) in states.enumerated() {
            try store.append(CleanEvent(
                ts: start + Int64(i) * gap, appID: state, domain: nil, state: state,
                durationS: gap, timeBucket: bucket, isWeekend: false
            ))
        }
    }
    return store
}

/// The same session repeated `times` times.
func repeated(_ times: Int, _ bucket: TimeBucket, _ states: [String]) -> [(TimeBucket, [String])] {
    Array(repeating: (bucket, states), count: times)
}
