import Sparkle

@MainActor
final class SparkleUpdateService: UpdateService {
    private let controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func isAutomaticCheckEnabled() -> Bool {
        controller.updater.automaticallyChecksForUpdates
    }

    func setAutomaticCheckEnabled(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func start() {
        controller.startUpdater()
    }
}
