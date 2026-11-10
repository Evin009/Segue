/// One thing to open next, with how strongly it's suggested.
public struct Suggestion: Equatable, Sendable {
    /// App ID, or app ID plus site, like `com.google.Chrome|github.com`.
    public let state: String
    public let score: Double

    public init(state: String, score: Double) {
        self.state = state
        self.score = score
    }
}
