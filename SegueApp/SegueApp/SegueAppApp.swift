import SwiftUI

@main
struct SegueAppApp: App {
    private let monitor: ActivityMonitor
    private let popup: PopupController
    private let hotKey: HotKey

    init() {
        let monitor = ActivityMonitor()
        let popup = PopupController(monitor: monitor)
        self.monitor = monitor
        self.popup = popup
        hotKey = HotKey { popup.toggle() }  // Option-Space
        monitor.start()
    }

    var body: some Scene {
        MenuBarExtra("Segue", systemImage: "arrow.turn.up.left") {
            if let problem = monitor.problem {
                Text(problem)
                Divider()
            }
            Button(monitor.isPaused ? "Start Monitoring" : "Stop Monitoring") {
                monitor.togglePause()
            }
            Button("Show Suggestions  ⌥Space") {
                popup.toggle()
            }
            Divider()
            Button("Quit Segue") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
