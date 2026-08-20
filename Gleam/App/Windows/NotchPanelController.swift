import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let appState: AppState
    private let mirrorViewModel: MirrorViewModel
    private let onboardingViewModel: OnboardingViewModel
    private let screenLocator: any NotchScreenLocating
    private let clock: any ClockService
    private let tracksPointer: Bool

    private var panel: MirrorPanel?
    private var host: NSHostingView<MirrorRootView>?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private var idleObservers: [NSObjectProtocol] = []
    private var lockObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?
    private var currentLayout: MirrorLayout?
    private var permissionPollCount = 0
    private var appliedStep: OnboardingStep?
    private var hasAppliedChrome = false
    private var hasBloomedOnboarding = false

    private static let permissionPollThreshold = 5

    init(
        appState: AppState,
        mirrorViewModel: MirrorViewModel,
        onboardingViewModel: OnboardingViewModel,
        screenLocator: (any NotchScreenLocating)? = nil,
        clock: (any ClockService)? = nil,
        tracksPointer: Bool = true
    ) {
        self.appState = appState
        self.mirrorViewModel = mirrorViewModel
        self.onboardingViewModel = onboardingViewModel
        self.screenLocator = screenLocator ?? NotchScreenLocator()
        self.clock = clock ?? LiveClockService()
        self.tracksPointer = tracksPointer
    }

    var isMirrorVisible: Bool {
        panel?.isVisible ?? false
    }

    var mirrorFrame: CGRect? {
        panel?.frame
    }

    var mirrorWindowNumber: Int? {
        panel?.windowNumber
    }

    func start() {
        installPointerMonitors()
        installScreenObserver()
        installIdleObservers()
        startRefreshLoop()
    }

    func stop() {
        removePointerMonitors()
        removeScreenObserver()
        removeIdleObservers()
        refreshTask?.cancel()
        refreshTask = nil
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Pointer tracking (event-driven)

    private func installPointerMonitors() {
        guard tracksPointer, globalMonitor == nil else { return }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            MainActor.assumeIsolated { self?.handlePointerMoved() }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            MainActor.assumeIsolated { self?.handlePointerMoved() }
            return event
        }
    }

    private func removePointerMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }

    // MARK: - Display topology

    private func installScreenObserver() {
        guard screenObserver == nil else { return }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLayoutAndPanel() }
        }
    }

    private func removeScreenObserver() {
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    // MARK: - Idle teardown

    // A plain screen lock keeps the session on-console, so no NSWorkspace notification reports it.
    private static let screenLockedNotification = Notification.Name("com.apple.screenIsLocked")

    private func installIdleObservers() {
        guard idleObservers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willSleepNotification,
            NSWorkspace.sessionDidResignActiveNotification
        ]
        idleObservers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.collapseMirror() }
            }
        }
        lockObserver = DistributedNotificationCenter.default().addObserver(
            forName: Self.screenLockedNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.collapseMirror() }
        }
    }

    private func removeIdleObservers() {
        let center = NSWorkspace.shared.notificationCenter
        idleObservers.forEach(center.removeObserver)
        idleObservers = []
        if let lockObserver {
            DistributedNotificationCenter.default().removeObserver(lockObserver)
        }
        lockObserver = nil
    }

    private func collapseMirror() {
        Task { [mirrorViewModel] in await mirrorViewModel.collapseImmediately() }
    }

    private func handlePointerMoved() {
        guard let layout = currentLayout else { return }
        if appState.onboardingStep != nil {
            if hasBloomedOnboarding {
                mirrorViewModel.showOnboarding()
            }
        } else {
            mirrorViewModel.updatePointer(NSEvent.mouseLocation, layout: layout)
        }
        applyPanelChrome()
    }

    // MARK: - Housekeeping (low-frequency)

    private static let onboardingBloomDelay = Duration.milliseconds(400)

    private func startRefreshLoop() {
        guard refreshTask == nil else { return }
        refreshTask = Task { [weak self, clock] in
            await self?.onboardingViewModel.prepare()
            self?.refreshLayoutAndPanel()
            if self?.appState.onboardingStep != nil {
                try? await clock.sleep(for: Self.onboardingBloomDelay)
                self?.hasBloomedOnboarding = true
                self?.mirrorViewModel.showOnboarding()
            }
            while Task.isCancelled == false {
                do {
                    try await clock.sleep(for: .seconds(1))
                } catch {
                    return
                }
                guard let self else { return }
                self.refreshLayoutAndPanel()
                self.applyPanelChrome()
                await self.refreshPermissionWhenNeeded()
            }
        }
    }

    private func refreshLayoutAndPanel() {
        guard let layout = screenLocator.currentLayout() else {
            dismissPanel()
            return
        }
        guard let panel else {
            currentLayout = layout
            configurePanel(layout: layout)
            return
        }
        if currentLayout != layout {
            currentLayout = layout
            panel.setFrame(layout.panelFrame, display: true)
            host?.rootView = makeRootView(notchSize: layout.notchSize)
        }
        if panel.isVisible == false {
            presentPanel(panel)
        }
        applyPanelChrome()
    }

    private func dismissPanel() {
        guard currentLayout != nil || panel != nil else { return }
        currentLayout = nil
        panel?.orderOut(nil)
        panel = nil
        host = nil
        collapseMirror()
    }

    private func refreshPermissionWhenNeeded() async {
        permissionPollCount += 1
        guard permissionPollCount >= Self.permissionPollThreshold else { return }
        permissionPollCount = 0
        await onboardingViewModel.refreshPermission()
    }

    // MARK: - Panel

    private func configurePanel(layout: MirrorLayout) {
        let panel = MirrorPanel(contentRect: layout.panelFrame)
        let host = NSHostingView(
            rootView: makeRootView(notchSize: layout.notchSize)
        )
        host.sizingOptions = []
        host.frame = panel.contentLayoutRect
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
        self.panel = panel
        self.host = host
        hasAppliedChrome = false
        applyPanelChrome()
        presentPanel(panel)
    }

    private func makeRootView(notchSize: CGSize) -> MirrorRootView {
        MirrorRootView(
            notchSize: notchSize,
            appState: appState,
            mirrorViewModel: mirrorViewModel,
            onboardingViewModel: onboardingViewModel
        )
    }

    private func presentPanel(_ panel: MirrorPanel) {
        if appState.onboardingStep != nil {
            panel.makeKeyAndOrderFront(nil)
            if hasBloomedOnboarding {
                mirrorViewModel.showOnboarding()
            }
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func applyPanelChrome() {
        guard let panel else { return }
        let step = appState.onboardingStep
        guard hasAppliedChrome == false || appliedStep != step else { return }
        hasAppliedChrome = true
        appliedStep = step
        panel.level = step == .permission ? .floating : .screenSaver
        panel.acceptsKey = step != nil
        if step == nil, panel.isKeyWindow {
            NSApp.deactivate()
        }
    }

    isolated deinit {
        refreshTask?.cancel()
        removePointerMonitors()
        removeScreenObserver()
        removeIdleObservers()
    }
}

private struct MirrorRootView: View {
    let notchSize: CGSize
    let appState: AppState
    let mirrorViewModel: MirrorViewModel
    let onboardingViewModel: OnboardingViewModel

    var body: some View {
        NotchMirrorView(notchSize: notchSize)
            .environment(appState)
            .environment(mirrorViewModel)
            .environment(onboardingViewModel)
    }
}
