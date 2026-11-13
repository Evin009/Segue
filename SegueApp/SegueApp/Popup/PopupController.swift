import AppKit
import Observation
import SegueCore
import SwiftUI

/// Shows the top suggestions in a small floating panel. Opened by hotkey; keeps your app in front.
@MainActor
@Observable
final class PopupController {
    struct Item: Identifiable {
        let id: String  // state
        let name: String
        let icon: NSImage
    }

    private(set) var items: [Item] = []
    private(set) var selected = 0

    @ObservationIgnored private let monitor: ActivityMonitor
    @ObservationIgnored private var context: PredictionContext?
    @ObservationIgnored private var panel: SuggestionPanel?
    @ObservationIgnored private var keyMonitor: Any?

    init(monitor: ActivityMonitor) {
        self.monitor = monitor
    }

    func toggle() {
        if panel?.isVisible == true { close() } else { show() }
    }

    private func show() {
        context = monitor.currentContext()
        items = context.map { monitor.suggestions(for: $0) }?.compactMap(Self.item) ?? []
        selected = 0

        let panel = panel ?? makePanel()
        self.panel = panel
        panel.position()
        panel.makeKeyAndOrderFront(nil)

        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Read what's needed here; NSEvent can't cross into the main actor closure.
            let keyCode = Int(event.keyCode)
            let characters = event.characters
            let used = MainActor.assumeIsolated { self?.handle(keyCode: keyCode, characters: characters) == true }
            return used ? nil : event
        }
    }

    /// Closes without feedback (clicked away, or pressed the hotkey again).
    func close() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.orderOut(nil)
    }

    /// Opens the suggestion and remembers it was accepted.
    func accept(_ index: Int) {
        guard items.indices.contains(index), let context else { return }
        let item = items[index]
        monitor.recordFeedback(in: context, suggested: item.id, accepted: true)
        close()
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: item.id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Esc: none of these were wanted. Each is ranked lower and hidden here for 4 hours.
    private func dismiss() {
        if let context {
            for item in items {
                monitor.recordFeedback(in: context, suggested: item.id, accepted: false)
            }
        }
        close()
    }

    /// Returns true if the key was used.
    private func handle(keyCode: Int, characters: String?) -> Bool {
        switch keyCode {
        case 53: dismiss()  // Esc
        case 36, 76: accept(selected)  // Return, Enter
        case 125: selected = min(selected + 1, max(items.count - 1, 0))  // Down
        case 126: selected = max(selected - 1, 0)  // Up
        default:
            guard let number = characters.flatMap(Int.init), (1...3).contains(number) else { return false }
            accept(number - 1)
        }
        return true
    }

    private func makePanel() -> SuggestionPanel {
        let panel = SuggestionPanel(content: SuggestionView(controller: self))
        panel.onResignKey = { [weak self] in self?.close() }
        return panel
    }

    /// App name and icon for a suggestion, or nil if the app is no longer installed.
    private static func item(for suggestion: Suggestion) -> Item? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: suggestion.state) else { return nil }
        return Item(
            id: suggestion.state,
            name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
            icon: NSWorkspace.shared.icon(forFile: url.path)
        )
    }
}

/// Floating panel that takes keyboard input without making Segue the active app.
final class SuggestionPanel: NSPanel {
    var onResignKey: (() -> Void)?

    init(content: some View) {
        super.init(contentRect: .zero, styleMask: [.nonactivatingPanel, .borderless], backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .floating
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        contentView = NSHostingView(rootView: content)
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        onResignKey?()
    }

    /// Centered horizontally, in the upper third of the screen with the mouse, like Spotlight.
    func position() {
        guard let content = contentView else { return }
        setContentSize(content.fittingSize)
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let area = screen?.visibleFrame else { return }
        setFrameOrigin(NSPoint(x: area.midX - frame.width / 2, y: area.maxY - area.height / 3 - frame.height / 2))
    }
}
