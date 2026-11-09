/// An app coming to the front, as reported by macOS, before cleaning.
public struct RawEvent: Equatable, Sendable {
    /// Unix time in seconds.
    public var ts: Int64
    /// Bundle ID, e.g. `com.tinyspeck.slackmacgap`.
    public var appID: String
    /// Active tab URL, only for tracked browsers.
    public var urlString: String?

    public init(ts: Int64, appID: String, urlString: String? = nil) {
        self.ts = ts
        self.appID = appID
        self.urlString = urlString
    }
}
