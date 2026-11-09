/// One finished, cleaned switch, ready to store.
public struct CleanEvent: Equatable, Sendable {
    /// Unix time in seconds when the state started.
    public var ts: Int64
    public var appID: String
    /// Site host such as `github.com`, only for tracked browsers.
    public var domain: String?
    /// `appID`, or `appID|domain` for browser sites.
    public var state: String
    /// Seconds spent in this state.
    public var durationS: Int64
    public var timeBucket: TimeBucket
    public var isWeekend: Bool

    public init(
        ts: Int64,
        appID: String,
        domain: String? = nil,
        state: String,
        durationS: Int64,
        timeBucket: TimeBucket,
        isWeekend: Bool
    ) {
        self.ts = ts
        self.appID = appID
        self.domain = domain
        self.state = state
        self.durationS = durationS
        self.timeBucket = timeBucket
        self.isWeekend = isWeekend
    }
}
