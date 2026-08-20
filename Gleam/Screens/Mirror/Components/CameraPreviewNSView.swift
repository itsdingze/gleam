import AppKit
import AVFoundation

final class CameraPreviewNSView: NSView {
    private let previewLayer: AVCaptureVideoPreviewLayer

    init(previewLayer: AVCaptureVideoPreviewLayer) {
        self.previewLayer = previewLayer
        super.init(frame: .zero)
        wantsLayer = true
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.setAffineTransform(CGAffineTransform(scaleX: -1, y: 1))
        // CALayer's default implicit animation makes the preview lag the SwiftUI frame animation.
        previewLayer.actions = ["bounds": NSNull(), "position": NSNull()]
        layer?.addSublayer(previewLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = bounds
        CATransaction.commit()
    }

    // AVCaptureVideoPreviewLayer defaults to contentsScale 1 and never adopts the window's Retina scale on its own.
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        adoptWindowBackingScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        adoptWindowBackingScale()
    }

    private func adoptWindowBackingScale() {
        guard let scale = window?.backingScaleFactor else { return }
        previewLayer.contentsScale = scale
        previewLayer.sublayers?.forEach { $0.contentsScale = scale }
    }
}
