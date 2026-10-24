import AppKit

@MainActor
final class SessionIdleObserver {
    // A plain screen lock keeps the session on-console, so no NSWorkspace notification reports it.
    private static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")

    private var workspaceObservers: [NSObjectProtocol] = []
    private var lockObserver: NSObjectProtocol?

    func start(onIdle: @escaping @MainActor () -> Void) {
        guard workspaceObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]
        workspaceObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated { onIdle() }
            }
        }
        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.screenLockedNotification,
            object: nil,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated { onIdle() }
        }
    }

    func stop() {
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
        workspaceObservers = []
        if let lockObserver {
            DistributedNotificationCenter.default().removeObserver(lockObserver)
        }
        lockObserver = nil
    }

    isolated deinit {
        stop()
    }
}
