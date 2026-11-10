import Foundation
import SegueCore

// Prints predictor vs baseline accuracy on your real Segue data.
// Usage: swift run --package-path Packages/SegueCore segue-eval [path/to/segue.sqlite]

let path = CommandLine.arguments.dropFirst().first
    ?? FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Segue/segue.sqlite").path

do {
    let events = try EventStore.snapshot(of: path).allEvents()
    let predictor = try Evaluator.evaluate(events, predict: Evaluator.predictor)
    let baseline = try Evaluator.evaluate(events, predict: Evaluator.baseline)
    print(EvalReport.text(events: events.count, predictor: predictor, baseline: baseline))
} catch {
    FileHandle.standardError.write(Data("Can't read \(path): \(error)\n".utf8))
    exit(1)
}
