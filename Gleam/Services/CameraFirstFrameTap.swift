import AVFoundation

nonisolated final class CameraFirstFrameTap: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, Sendable {
    let frames: AsyncStream<Void>

    private let continuation: AsyncStream<Void>.Continuation

    override init() {
        (frames, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
        super.init()
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        markFrameDelivered()
    }

    func markFrameDelivered() {
        continuation.yield()
    }

    deinit {
        continuation.finish()
    }
}
