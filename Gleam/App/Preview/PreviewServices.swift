#if DEBUG
import AVFoundation

actor PreviewCameraPermissionService: CameraPermissionService {
    private let permission: CameraPermission

    init(permission: CameraPermission) {
        self.permission = permission
    }

    func currentPermission() -> CameraPermission {
        permission
    }

    func requestPermission() -> CameraPermission {
        permission
    }

    func openSystemSettings() {}
}

actor PreviewCameraCaptureService: CameraCaptureService {
    func prepare() {}
    func start() {}
    func stop() {}

    func makePreviewLayer() -> CameraPreviewLayerBox {
        CameraPreviewLayerBox(layer: AVCaptureVideoPreviewLayer())
    }

    func setFailureHandler(_ handler: @escaping @Sendable (CameraCaptureError) -> Void) {}
}

final class PreviewOnboardingStore: OnboardingStore {
    func hasCompletedOnboarding() -> Bool { false }
    func markOnboardingCompleted() {}
}

final class PreviewUpdateService: UpdateService {
    private var isEnabled = true

    func isAutomaticCheckEnabled() -> Bool { isEnabled }
    func setAutomaticCheckEnabled(_ enabled: Bool) { isEnabled = enabled }
    func start() {}
}

final class PreviewLoginItemService: LoginItemService {
    private var enabled = false

    func isEnabled() -> Bool { enabled }
    func setEnabled(_ enabled: Bool) { self.enabled = enabled }
}
#endif
