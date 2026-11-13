/// Recording rules: sends app switches through the cleaner into the store, and handles pause,
/// resume, screen lock, user switching, and interruptions like sleep.
public struct ActivityRecorder {
    private var cleaner: EventCleaner
    private let store: EventStore
    public private(set) var isPaused = false
    /// Screen locked or another Mac user active. Nothing is recorded until unlock.
    public private(set) var isLocked = false
    /// Events saved so far. Lets callers tell whether a call really saved something.
    public private(set) var savedCount = 0

    public init(cleaner: EventCleaner, store: EventStore) {
        self.cleaner = cleaner
        self.store = store
    }

    /// States held but not yet saved, oldest first.
    public var heldStates: [String] { cleaner.heldStates }

    /// When the oldest held state started.
    public var heldSince: Int64? { cleaner.heldSince }

    private var isRecording: Bool { !isPaused && !isLocked }

    public mutating func appActivated(_ appID: String, at ts: Int64) throws {
        guard isRecording else { return }
        try save(cleaner.ingest(RawEvent(ts: ts, appID: appID)))
    }

    /// Saves what is held. Use for sleep and quit.
    public mutating func interrupt(at ts: Int64) throws {
        try save(cleaner.flush(at: ts))
    }

    /// Display or Mac woke. Ignored while locked, since the lock screen may still be showing.
    public mutating func wake(frontAppID: String?, at ts: Int64) throws {
        try record(frontAppID, at: ts)
    }

    /// Screen locked, or another Mac user became active.
    public mutating func lock(at ts: Int64) throws {
        isLocked = true
        try interrupt(at: ts)
    }

    public mutating func unlock(frontAppID: String?, at ts: Int64) throws {
        isLocked = false
        try record(frontAppID, at: ts)
    }

    /// Pause sticks even if saving what's held fails.
    public mutating func pause(at ts: Int64) throws {
        isPaused = true
        try interrupt(at: ts)
    }

    public mutating func resume(frontAppID: String?, at ts: Int64) throws {
        isPaused = false
        try record(frontAppID, at: ts)
    }

    private mutating func record(_ appID: String?, at ts: Int64) throws {
        if let appID {
            try appActivated(appID, at: ts)
        }
    }

    private mutating func save(_ events: [CleanEvent]) throws {
        for event in events {
            try store.append(event)
            savedCount += 1
        }
    }
}
