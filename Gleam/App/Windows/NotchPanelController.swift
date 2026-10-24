import AppKit
import SwiftUI

@MainActor
final class NotchPanelController {
    private let appState: AppState
    private let mirrorViewModel: MirrorViewModel
    private let onboardingViewModel: OnboardingViewModel
    private let screenLocator: any NotchScreenLocating
    private let clock: any ClockService
    private let notificationCenter: NotificationCenter
    private let tracksPointer: Bool

    private var panel: MirrorPanel?
    private var host: NSHostingView<MirrorRootView>?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var screenObserver: NSObjectProtocol?
    private let idleObserver = SessionIdleObserver()
    private var launchTask: Task<Void, Never>?
    private var chromeTask: Task<Void, Never>?
    private var permissionWatchTask: Task<Void, Never>?
    private var permissionCheckTask: Task<Void, Never>?
    private var currentLayout: MirrorLayout?
    private var appliedStep: OnboardingStep?
    private var hasAppliedChrome = false
    private var hasBloomedOnboarding = false

    private static let permissionCheckInterval = Duration.seconds(5)

    init(
        appState: AppState,
        mirrorViewModel: MirrorViewModel,
        onboardingViewModel: OnboardingViewModel,
        screenLocator: (any NotchScreenLocating)? = nil,
        clock: (any ClockService)? = nil,
        notificationCenter: NotificationCenter = .default,
        tracksPointer: Bool = true
    ) {
        self.appState = appState
        self.mirrorViewModel = mirrorViewModel
        self.onboardingViewModel = onboardingViewModel
        self.screenLocator = screenLocator ?? NotchScreenLocator()
        self.clock = clock ?? LiveClockService()
        self.notificationCenter = notificationCenter
        self.tracksPointer = tracksPointer
    }

    var isMirrorVisible: Bool {
        panel?.isVisible ?? false
    }

    var mirrorLevel: NSWindow.Level? {
        panel?.level
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
        idleObserver.start { [weak self] in self?.collapseMirror() }
        startLaunchSequence()
    }

    func stop() {
        removePointerMonitors()
        removeScreenObserver()
        idleObserver.stop()
        cancelTasks()
        panel?.orderOut(nil)
        panel = nil
    }

    private func cancelTasks() {
        for task in [launchTask, chromeTask, permissionWatchTask, permissionCheckTask] {
            task?.cancel()
        }
        launchTask = nil
        chromeTask = nil
        permissionWatchTask = nil
        permissionCheckTask = nil
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
        screenObserver = notificationCenter.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.refreshLayoutAndPanel() }
        }
    }

    private func removeScreenObserver() {
        if let screenObserver { notificationCenter.removeObserver(screenObserver) }
        screenObserver = nil
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

    // MARK: - Launch

    private static let onboardingBloomDelay = Duration.milliseconds(400)

    private func startLaunchSequence() {
        guard launchTask == nil else { return }
        launchTask = Task { [weak self, clock] in
            await self?.onboardingViewModel.prepare()
            guard Task.isCancelled == false else { return }
            self?.refreshLayoutAndPanel()
            self?.observeOnboardingStep()
            self?.observeCameraPermission()
            guard self?.appState.onboardingStep != nil else { return }
            do {
                try await clock.sleep(for: Self.onboardingBloomDelay)
            } catch {
                return
            }
            self?.hasBloomedOnboarding = true
            self?.mirrorViewModel.showOnboarding()
        }
    }

    private func observeOnboardingStep() {
        chromeTask = Task { [weak self, appState] in
            for await _ in Observations({ appState.onboardingStep }) {
                self?.applyPanelChrome()
            }
        }
    }

    // MARK: - Camera permission

    private func observeCameraPermission() {
        permissionWatchTask = Task { [weak self, appState] in
            for await isAwaiting in Observations({ appState.isAwaitingCameraPermission }) where isAwaiting {
                self?.startPermissionChecksIfIdle()
            }
        }
    }

    private func startPermissionChecksIfIdle() {
        guard permissionCheckTask == nil else { return }
        permissionCheckTask = Task { [weak self, appState, clock] in
            defer { self?.permissionCheckTask = nil }
            while appState.isAwaitingCameraPermission {
                do {
                    try await clock.sleep(for: Self.permissionCheckInterval)
                } catch {
                    return
                }
                guard let onboardingViewModel = self?.onboardingViewModel else { return }
                await onboardingViewModel.refreshPermission()
            }
        }
    }

    // MARK: - Layout

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
        cancelTasks()
        removePointerMonitors()
        removeScreenObserver()
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
