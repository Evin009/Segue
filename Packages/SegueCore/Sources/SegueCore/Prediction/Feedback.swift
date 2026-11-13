/// How often a suggestion was accepted or dismissed in one context.
public struct Feedback: Equatable, Sendable {
    public var accepts: Int
    public var dismisses: Int

    public init(accepts: Int, dismisses: Int) {
        self.accepts = accepts
        self.dismisses = dismisses
    }
}
