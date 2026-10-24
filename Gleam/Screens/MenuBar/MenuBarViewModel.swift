import AppKit
import Observation
import os

@MainActor
@Observable
final class MenuBarViewModel {
    private let appState: AppState
    private let permission: any CameraPermissionService
    private let loginItem: any LoginItemService
    private let updates: any UpdateService
    private let mirror: MirrorViewModel
    private let logger = Logger(category: "menubar")
    private let bundle: Bundle

    private var isShowingLaunchAtStartup = false

    var launchAtStartup: Bool {
        didSet { applyLaunchAtStartup() }
    }

    var autoUpdateEnabled: Bool {
        didSet { updates.setAutomaticCheckEnabled(autoUpdateEnabled) }
    }

    init(
        appState: AppState,
        permission: any CameraPermissionService,
        loginItem: any LoginItemService,
        updates: any UpdateService,
        mirror: MirrorViewModel,
        bundle: Bundle = .main
    ) {
        self.appState = appState
        self.permission = permission
        self.loginItem = loginItem
        self.updates = updates
        self.mirror = mirror
        self.bundle = bundle
        self.launchAtStartup = loginItem.isEnabled()
        self.autoUpdateEnabled = updates.isAutomaticCheckEnabled()
    }

    var phase: AppPhase {
        appState.phase
    }

    var isOn: Bool {
        appState.phase == .active
    }

    var canTogglePause: Bool {
        appState.onboardingStep == nil && appState.cameraPermission == .authorized
    }

    var actionTitle: String {
        appState.isPaused ? "Resume" : "Pause"
    }

    var actionIsResume: Bool {
        appState.isPaused
    }

    var versionLabel: String {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return ""
        }
        return "v\(version)"
    }

    func togglePause() {
        guard canTogglePause else { return }
        appState.isPaused.toggle()
        guard appState.isPaused else { return }
        Task { [mirror] in await mirror.collapseImmediately() }
    }

    func menuDidOpen() {
        showLaunchAtStartup(loginItem.isEnabled())
        Task { [appState, permission] in
            appState.cameraPermission = await permission.currentPermission()
        }
    }

    private func applyLaunchAtStartup() {
        guard isShowingLaunchAtStartup == false else { return }
        do {
            try loginItem.setEnabled(launchAtStartup)
        } catch {
            logger.error("Login item update failed: \(error.localizedDescription, privacy: .public)")
            showLaunchAtStartup(!launchAtStartup)
        }
    }

    private func showLaunchAtStartup(_ enabled: Bool) {
        isShowingLaunchAtStartup = true
        launchAtStartup = enabled
        isShowingLaunchAtStartup = false
    }

    func openSystemSettings() {
        Task { await permission.openSystemSettings() }
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }
}
