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

        let distributed = DistributedNotificationCenter.default()
        let signals: [(NotificationCenter, Notification.Name, Signal)] = [
            (workspace, NSWorkspace.willSleepNotification, .interrupt),
            (workspace, NSWorkspace.screensDidSleepNotification, .interrupt),
            (NotificationCenter.default, NSApplication.willTerminateNotification, .interrupt),
            (distributed, Notification.Name("com.apple.screenIsLocked"), .lock),
            (workspace, NSWorkspace.sessionDidResignActiveNotification, .lock),
            (distributed, Notification.Name("com.apple.screenIsUnlocked"), .unlock),
            (workspace, NSWorkspace.sessionDidBecomeActiveNotification, .unlock),
            (workspace, NSWorkspace.didWakeNotification, .wake),
            (workspace, NSWorkspace.screensDidWakeNotification, .wake),
        ]
        for (center, name, signal) in signals {
            observe(center, name) { _ in nil } then: { monitor, _ in
                monitor.handle(signal)
            }
        }

        handle(.wake)
    }

    private enum Signal {
        /// Sleep or quit: save what's held.
        case interrupt
        /// Screen locked or another Mac user active: save, then record nothing until unlock.
        case lock
        case unlock
        /// Mac or display woke. Ignored by the recorder while locked.
        case wake
    }

    private func handle(_ signal: Signal) {
        let ts = Self.now()
        let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        switch signal {
        case .interrupt: record { try $0.interrupt(at: ts) }
        case .lock: record { try $0.lock(at: ts) }
        case .unlock: record { try $0.unlock(frontAppID: front, at: ts) }
        case .wake: record { try $0.wake(frontAppID: front, at: ts) }
        }
    }

    func togglePause() {
        if isPaused {
            let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            record { try $0.resume(frontAppID: front, at: Self.now()) }
        } else {
            record { try $0.pause(at: Self.now()) }
        }
    }

    private func record(_ action: (inout ActivityRecorder) throws -> Void) {
        guard var current = recorder else { return }
        do {
            try action(&current)
            problem = nil
        } catch {
            problem = "Couldn't save activity: \(error.localizedDescription)"
        }
        recorder = current
        isPaused = current.isPaused
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
