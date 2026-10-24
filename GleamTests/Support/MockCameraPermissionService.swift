@testable import Gleam

actor MockCameraPermissionService: CameraPermissionService {
    private var permission: CameraPermission

    init(permission: CameraPermission) {
        self.permission = permission
    }

    func change(to permission: CameraPermission) {
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
