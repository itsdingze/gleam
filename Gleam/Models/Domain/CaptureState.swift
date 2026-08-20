enum CaptureState: Equatable, Sendable {
    case idle
    case starting
    case running
    case failed(CameraCaptureError)

    var isActive: Bool {
        switch self {
        case .starting, .running: true
        case .idle, .failed: false
        }
    }
}
