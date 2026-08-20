import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let container = DependencyContainer()

    private var panelController: NotchPanelController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests are hosted inside this app, so `xcodebuild test` launches it.
        guard isRunningAsTestHost == false else { return }

        let panelController = NotchPanelController(
            appState: container.appState,
            mirrorViewModel: container.mirrorViewModel,
            onboardingViewModel: container.onboardingViewModel
        )
        self.panelController = panelController
        panelController.start()
        container.updateService.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        panelController?.stop()
    }

    private var isRunningAsTestHost: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
