import AppKit
import AVFoundation

struct AVCameraPermissionService: CameraPermissionService {
    nonisolated init() {}

    func currentPermission() async -> CameraPermission {
        permission(from: AVCaptureDevice.authorizationStatus(for: .video))
    }

    @MainActor
    func requestPermission() async -> CameraPermission {
        if AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined {
            NSApp.activate()
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        return await currentPermission()
    }

    @MainActor
    func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func permission(from status: AVAuthorizationStatus) -> CameraPermission {
        switch status {
        case .authorized:
            .authorized
        case .notDetermined:
            .notDetermined
        case .denied, .restricted:
            .denied
        @unknown default:
            .denied
        }
    }
}
