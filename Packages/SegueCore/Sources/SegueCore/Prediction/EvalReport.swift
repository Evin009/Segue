import Foundation

/// Plain-text table comparing the predictor with the baseline.
public enum EvalReport {
    /// Fewer switches than this and the numbers mostly reflect luck.
    public static let minTargets = 100

    public static func text(events: Int, predictor: EvalResult, baseline: EvalResult) -> String {
        var lines = [
            "\(events) events, \(predictor.targets) switches to guess",
            "",
            row("", "Predictor", "Baseline", "Diff"),
            row("Top-1", predictor.top1Accuracy, baseline.top1Accuracy),
            row("Top-3", predictor.top3Accuracy, baseline.top3Accuracy),
            row("Coverage", predictor.coverage, baseline.coverage),
        ]
        if predictor.targets < minTargets {
            lines += ["", "Too little data: under \(minTargets) switches. Keep Segue running and try again in a few days."]
        }
        return lines.joined(separator: "\n")
    }

    private static func row(_ label: String, _ ours: Double, _ theirs: Double) -> String {
        row(label, percent(ours), percent(theirs), String(format: "%+.1f", (ours - theirs) * 100))
    }

    private static func row(_ label: String, _ a: String, _ b: String, _ c: String) -> String {
        label.padding(toLength: 10, withPad: " ", startingAt: 0) + pad(a, 11) + pad(b, 11) + pad(c, 9)
    }

    private static func percent(_ value: Double) -> String {
        String(format: "%.1f%%", value * 100)
    }

    private static func pad(_ text: String, _ width: Int) -> String {
        String(repeating: " ", count: max(0, width - text.count)) + text
    }
}
