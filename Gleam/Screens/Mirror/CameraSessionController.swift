import AVFoundation
import Observation

@MainActor
@Observable
final class CameraSessionController {
    private let capture: any CameraCaptureService
    private let logger: any LoggerService

    private var task: Task<Void, Never>?
    private var generation = 0
    private var hasPrepared = false

    private(set) var state: CaptureState = .idle
    private(set) var previewLayer: AVCaptureVideoPreviewLayer?

    init(capture: any CameraCaptureService, logger: any LoggerService) {
        self.capture = capture
        self.logger = logger
    }

    func prepareIfNeeded() {
        guard hasPrepared == false else { return }
        hasPrepared = true
        Task { [capture, weak self] in
            await capture.setFailureHandler { error in
                Task { @MainActor in self?.applyMidSessionFailure(error) }
            }
            await capture.prepare()
        }
    }

    func startIfIdle() {
        switch state {
        case .starting, .running:
            return
        case .idle, .failed:
            break
        }
        generation += 1
        let generation = generation
        state = .starting
        let previous = task
        task = Task { [weak self, capture, logger] in
            await previous?.value
            do {
                try await capture.start()
                let preview = await capture.makePreviewLayer()
                self?.applyRunning(preview.layer, generation: generation)
            } catch let error as CameraCaptureError {
                logger.error("Capture failed: \(String(describing: error))")
                self?.applyFailed(error, generation: generation)
            } catch {
                logger.error("Capture failed: \(String(describing: error))")
                self?.applyFailed(.cameraUnavailable, generation: generation)
            }
        }
    }

    func stopIfNeeded() {
        guard state != .idle else { return }
        generation += 1
        previewLayer = nil
        state = .idle
        stopAfterPendingWork()
    }

    func waitForPendingWork() async {
        await task?.value
    }

    private func applyMidSessionFailure(_ error: CameraCaptureError) {
        guard state.isActive else { return }
        generation += 1
        previewLayer = nil
        state = .failed(error)
        stopAfterPendingWork()
    }

    private func stopAfterPendingWork() {
        let previous = task
        task = Task { [capture] in
            await previous?.value
            await capture.stop()
        }
    }

    private func applyRunning(_ layer: AVCaptureVideoPreviewLayer, generation: Int) {
        guard self.generation == generation else { return }
        previewLayer = layer
        state = .running
    }

    private func applyFailed(_ error: CameraCaptureError, generation: Int) {
        guard self.generation == generation else { return }
        previewLayer = nil
        state = .failed(error)
    }

    isolated deinit {
        task?.cancel()
    }
}
