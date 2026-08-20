import Observation
import SwiftUI

@MainActor
@Observable
final class DependencyContainer {
    let appState: AppState
    let updateService: any UpdateService
    let mirrorViewModel: MirrorViewModel
    let onboardingViewModel: OnboardingViewModel
    let menuBarViewModel: MenuBarViewModel

    init(
        appState: AppState? = nil,
        permissionService: (any CameraPermissionService)? = nil,
        onboardingStore: (any OnboardingStore)? = nil,
        cameraService: (any CameraCaptureService)? = nil,
        clock: (any ClockService)? = nil,
        logger: (any LoggerService)? = nil,
        updateService: (any UpdateService)? = nil,
        loginItemService: (any LoginItemService)? = nil
    ) {
        let appState = appState ?? AppState()
        let logger = logger ?? OSLogLoggerService()
        let permissionService = permissionService ?? AVCameraPermissionService()
        let onboardingStore = onboardingStore ?? UserDefaultsOnboardingStore()
        let cameraService = cameraService ?? AVCameraCaptureService(logger: logger)
        let clock = clock ?? LiveClockService()
        let updateService = updateService ?? SparkleUpdateService()
        let loginItemService = loginItemService ?? SMAppLoginItemService()
        self.appState = appState
        self.updateService = updateService

        let mirrorViewModel = MirrorViewModel(
            appState: appState,
            capture: cameraService,
            clock: clock,
            logger: logger
        )

        self.mirrorViewModel = mirrorViewModel
        self.onboardingViewModel = OnboardingViewModel(
            appState: appState,
            permission: permissionService,
            store: onboardingStore,
            mirrorViewModel: mirrorViewModel,
            clock: clock
        )
        self.menuBarViewModel = MenuBarViewModel(
            appState: appState,
            permission: permissionService,
            loginItem: loginItemService,
            updates: updateService,
            mirror: mirrorViewModel,
            logger: logger
        )
    }
}
