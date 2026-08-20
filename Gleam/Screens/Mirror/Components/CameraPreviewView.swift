import AVFoundation
import SwiftUI

struct CameraPreviewView: NSViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> CameraPreviewNSView {
        CameraPreviewNSView(previewLayer: previewLayer)
    }

    func updateNSView(_ nsView: CameraPreviewNSView, context: Context) {}
}
