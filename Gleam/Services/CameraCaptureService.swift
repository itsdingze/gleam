import AVFoundation

nonisolated struct CameraPreviewLayerBox: @unchecked Sendable {
    let layer: AVCaptureVideoPreviewLayer
}

protocol CameraCaptureService: Sendable {
    func prepare() async
    func start() async throws
    func stop() async
    func makePreviewLayer() async -> CameraPreviewLayerBox
    func setFailureHandler(_ handler: @escaping @Sendable (CameraCaptureError) -> Void) async
}
