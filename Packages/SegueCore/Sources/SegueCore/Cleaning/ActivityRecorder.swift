/// Recording rules: sends app switches through the cleaner into the store, and handles pause,
/// resume, and interruptions like sleep or screen lock.
public struct ActivityRecorder {
    private var cleaner: EventCleaner
    private let store: EventStore
    public private(set) var isPaused = false

    public init(cleaner: EventCleaner, store: EventStore) {
        self.cleaner = cleaner
        self.store = store
    }

    /// States held but not yet saved, oldest first.
    public var heldStates: [String] { cleaner.heldStates }

    public mutating func appActivated(_ appID: String, at ts: Int64) throws {
        guard !isPaused else { return }
        try save(cleaner.ingest(RawEvent(ts: ts, appID: appID)))
    }

    /// Saves what is held. Use for sleep, screen lock, and quit.
    public mutating func interrupt(at ts: Int64) throws {
        try save(cleaner.flush(at: ts))
    }

    public mutating func pause(at ts: Int64) throws {
        try interrupt(at: ts)
        isPaused = true
    }

    public mutating func resume(frontAppID: String?, at ts: Int64) throws {
        isPaused = false
        if let frontAppID {
            try appActivated(frontAppID, at: ts)
        }
    }

    private func save(_ events: [CleanEvent]) throws {
        for event in events {
            try store.append(event)
        }
    }
}
