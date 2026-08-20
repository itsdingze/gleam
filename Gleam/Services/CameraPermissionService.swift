protocol CameraPermissionService: Sendable {
    func currentPermission() async -> CameraPermission
    func requestPermission() async -> CameraPermission
    func openSystemSettings() async
}
