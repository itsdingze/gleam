import AVFoundation
@testable import Gleam

actor MockCameraCaptureService: CameraCaptureService {
    private let session = AVCaptureSession()
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var prepareCount = 0
    private var startError: (any Error)?
    private var isStartHeld = false
    private var startGate: CheckedContinuation<Void, Never>?
    private var failureHandler: (@Sendable (CameraCaptureError) -> Void)?

    func setStartError(_ error: any Error) {
        startError = error
    }

    func holdStart() {
        isStartHeld = true
    }

    func releaseStart() {
        isStartHeld = false
        startGate?.resume()
        startGate = nil
    }

    func prepare() {
        prepareCount += 1
    }

    func start() async throws {
        startCount += 1
        if let startError {
            throw startError
        }
        if isStartHeld {
            await withCheckedContinuation { startGate = $0 }
        }
    }

    func stop() {
        stopCount += 1
    }

    func makePreviewLayer() -> CameraPreviewLayerBox {
        CameraPreviewLayerBox(layer: AVCaptureVideoPreviewLayer(session: session))
    }

    func setFailureHandler(_ handler: @escaping @Sendable (CameraCaptureError) -> Void) {
        failureHandler = handler
    }

    func failMidSession(_ error: CameraCaptureError) {
        failureHandler?(error)
    }
}
