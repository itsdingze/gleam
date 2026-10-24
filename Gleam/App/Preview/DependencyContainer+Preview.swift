#if DEBUG
extension DependencyContainer {
    static func preview(
        onboardingStep: OnboardingStep? = nil,
        cameraPermission: CameraPermission = .authorized,
        isPaused: Bool = false
    ) -> DependencyContainer {
        let appState = AppState(onboardingStep: onboardingStep, cameraPermission: cameraPermission)
        appState.isPaused = isPaused
        return DependencyContainer(
            appState: appState,
            permissionService: PreviewCameraPermissionService(permission: cameraPermission),
            onboardingStore: PreviewOnboardingStore(),
            cameraService: PreviewCameraCaptureService(),
            clock: LiveClockService(),
            updateService: PreviewUpdateService(),
            loginItemService: PreviewLoginItemService()
        )
    }
}
#endif
