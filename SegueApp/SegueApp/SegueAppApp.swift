import SwiftUI

@main
struct SegueAppApp: App {
    var body: some Scene {
        MenuBarExtra("Segue", systemImage: "arrow.turn.up.left") {
            Button("Quit Segue") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
