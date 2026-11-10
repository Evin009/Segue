import SwiftUI

@main
struct SegueAppApp: App {
    private let monitor: ActivityMonitor

    init() {
        monitor = ActivityMonitor()
        monitor.start()
    }

    var body: some Scene {
        MenuBarExtra("Segue", systemImage: "arrow.turn.up.left") {
            if let problem = monitor.problem {
                Text(problem)
                Divider()
            }
            Button(monitor.isPaused ? "Resume Tracking" : "Pause Tracking") {
                monitor.togglePause()
            }
            Divider()
            Button("Quit Segue") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
