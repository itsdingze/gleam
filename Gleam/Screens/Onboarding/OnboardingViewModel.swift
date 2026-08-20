import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    private static let collapseRideOut = Duration.milliseconds(400)

    private let appState: AppState
    private let permission: any CameraPermissionService
    private let store: any OnboardingStore
    private let mirrorViewModel: MirrorViewModel
    private let clock: any ClockService

    private(set) var isRequestingPermission = false

    init(
        appState: AppState,
        permission: any CameraPermissionService,
        store: any OnboardingStore,
        mirrorViewModel: MirrorViewModel,
        clock: any ClockService = LiveClockService()
    ) {
        self.appState = appState
        self.permission = permission
        self.store = store
        self.mirrorViewModel = mirrorViewModel
        self.clock = clock
    }

    var step: OnboardingStep? {
        appState.onboardingStep
    }

    var cameraPermission: CameraPermission {
        appState.cameraPermission
    }

    func prepare() async {
        let currentPermission = await permission.currentPermission()
        appState.cameraPermission = currentPermission

        if store.hasCompletedOnboarding(), currentPermission == .authorized {
            appState.onboardingStep = nil
        }
    }

    func next() {
        switch appState.onboardingStep {
        case .welcome:
            appState.onboardingStep = .instructions
        case .instructions:
            appState.onboardingStep = .permission
        case .permission, .none:
            break
        }
    }

    func requestCameraPermission() async {
        guard isRequestingPermission == false else { return }
        isRequestingPermission = true
        let result = await permission.requestPermission()
        appState.cameraPermission = result
        isRequestingPermission = false
        if result == .authorized {
            await finish()
        }
    }

    func refreshPermission() async {
        let currentPermission = await permission.currentPermission()
        appState.cameraPermission = currentPermission
        if appState.onboardingStep == .permission, currentPermission == .authorized {
            await finish()
        }
    }

    func openSystemSettings() {
        Task { await permission.openSystemSettings() }
    }

    private func finish() async {
        store.markOnboardingCompleted()
        mirrorViewModel.finishOnboarding()
        try? await clock.sleep(for: Self.collapseRideOut)
        appState.onboardingStep = nil
        mirrorViewModel.playWelcomePeek()
    }
}
