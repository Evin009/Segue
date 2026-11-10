import AppKit
import Observation
import SegueCore

/// Listens to macOS for app switches, sleep, screen lock, and quit, and passes them to the recorder.
@MainActor
@Observable
final class ActivityMonitor {
    private(set) var isPaused = false
    /// Shown in the menu when something goes wrong.
    private(set) var problem: String?

    @ObservationIgnored private var recorder: ActivityRecorder?
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init() {
        do {
            let store = try EventStore(path: Self.databasePath())
            recorder = ActivityRecorder(
                cleaner: EventCleaner(config: .standard, calendar: .autoupdatingCurrent),
                store: store
            )
        } catch {
            problem = "Can't open database: \(error.localizedDescription)"
        }
    }

    func start() {
        guard recorder != nil, observers.isEmpty else { return }

        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            return app?.bundleIdentifier
        } then: { monitor, appID in
            if let appID { monitor.record { try $0.appActivated(appID, at: Self.now()) } }
        }

        let interruptions: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.willSleepNotification),
            (workspace, NSWorkspace.screensDidSleepNotification),
            (DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsLocked")),
            (NotificationCenter.default, NSApplication.willTerminateNotification),
        ]
        for (center, name) in interruptions {
            observe(center, name) { _ in nil } then: { monitor, _ in
                monitor.record { try $0.interrupt(at: Self.now()) }
            }
        }

        let returns: [(NotificationCenter, Notification.Name)] = [
            (workspace, NSWorkspace.didWakeNotification),
            (workspace, NSWorkspace.screensDidWakeNotification),
            (DistributedNotificationCenter.default(), Notification.Name("com.apple.screenIsUnlocked")),
        ]
        for (center, name) in returns {
            observe(center, name) { _ in nil } then: { monitor, _ in
                monitor.recordFrontApp()
            }
        }

        recordFrontApp()
    }

    func togglePause() {
        if isPaused {
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            record { try $0.resume(frontAppID: front, at: Self.now()) }
        } else {
            record { try $0.pause(at: Self.now()) }
        }
        isPaused = recorder?.isPaused ?? false
    }

    private func recordFrontApp() {
        guard let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return }
        record { try $0.appActivated(front, at: Self.now()) }
    }

    private func record(_ action: (inout ActivityRecorder) throws -> Void) {
        guard var current = recorder else { return }
        do {
            try action(&current)
        } catch {
            problem = "Couldn't save activity: \(error.localizedDescription)"
        }
        recorder = current
    }

    /// Reads what's needed from the notification on the main queue, then hands it to the monitor.
    private func observe(
        _ center: NotificationCenter,
        _ name: Notification.Name,
        read: @escaping @Sendable (Notification) -> String?,
        then handle: @escaping @MainActor (ActivityMonitor, String?) -> Void
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
            let value = read(note)
            MainActor.assumeIsolated {
                guard let self else { return }
                handle(self, value)
            }
        }
        observers.append((center, token))
    }

    private static func now() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }

    private static func databasePath() throws -> String {
        let folder = try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("Segue", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("segue.sqlite").path
    }
}
