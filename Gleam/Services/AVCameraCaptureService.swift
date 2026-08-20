import AVFoundation

actor AVCameraCaptureService: CameraCaptureService {
    // AVCaptureSession's start/stop and configuration calls block, so the actor runs on its own
    // serial queue instead of the cooperative pool.
    private let queue = DispatchSerialQueue(label: "com.dingze.Gleam.camera-session")

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        queue.asUnownedSerialExecutor()
    }

    private let session = AVCaptureSession()
    private let logger: any LoggerService
    private var isConfigured = false
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var frameTapOutput: AVCaptureVideoDataOutput?
    private var frameTap: CameraFirstFrameTap?
    private var runtimeErrorTask: Task<Void, Never>?
    private var failureHandler: (@Sendable (CameraCaptureError) -> Void)?

    // Cameras can briefly report as absent right after the permission grant propagates.
    private nonisolated static let deviceAcquisitionAttempts = 3
    private nonisolated static let deviceRetryDelay: TimeInterval = 0.2
    private nonisolated static let firstFrameTimeout = Duration.milliseconds(1_500)

    init(logger: any LoggerService = OSLogLoggerService(category: "camera")) {
        self.logger = logger
    }

    func prepare() {
        do {
            try configureIfNeeded()
        } catch {
            logger.error("Camera prepare failed: \(String(describing: error))")
        }
    }

    func start() async throws {
        let tap: CameraFirstFrameTap
        do {
            try configureIfNeeded()
            tap = ensureFrameTap()
            if session.isRunning == false {
                session.startRunning()
            }
        } catch {
            logger.error("Camera start failed: \(String(describing: error))")
            throw error
        }
        await waitForFirstFrame(tap)
        // Removing the output, not just its delegate, frees its frame buffer pool; a nil-delegate output keeps the pool allocated.
        removeFrameTapOutput()
    }

    func stop() {
        if session.isRunning {
            session.stopRunning()
        }
    }

    func makePreviewLayer() -> CameraPreviewLayerBox {
        let layer = previewLayer ?? AVCaptureVideoPreviewLayer(session: session)
        previewLayer = layer
        return CameraPreviewLayerBox(layer: layer)
    }

    func setFailureHandler(_ handler: @escaping @Sendable (CameraCaptureError) -> Void) {
        failureHandler = handler
    }

    private func waitForFirstFrame(_ tap: CameraFirstFrameTap) async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                for await _ in tap.frames { return }
            }
            group.addTask {
                try? await Task.sleep(for: Self.firstFrameTimeout)
            }
            await group.next()
            group.cancelAll()
        }
    }

    // MARK: - Session configuration

    private func configureIfNeeded() throws {
        guard isConfigured == false else { return }
        try configure()
        isConfigured = true
        observeRuntimeErrors()
    }

    private func configure() throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        session.inputs.forEach(session.removeInput)
        session.outputs.forEach(session.removeOutput)
        frameTapOutput = nil
        frameTap = nil

        session.sessionPreset = .hd1280x720

        guard let camera = resolveCamera() else {
            throw CameraCaptureError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input) else {
            throw CameraCaptureError.inputUnavailable
        }
        session.addInput(input)

        addFirstFrameTap()

        // Attaching the preview layer after startRunning() forces a pipeline rebuild.
        previewLayer = AVCaptureVideoPreviewLayer(session: session)
    }

    @discardableResult
    private func addFirstFrameTap() -> CameraFirstFrameTap {
        let tap = CameraFirstFrameTap()
        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        // The camera emits bi-planar YUV natively; the default BGRA inserts a conversion stage with its own buffer pool.
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        ]
        output.setSampleBufferDelegate(tap, queue: queue)
        if session.canAddOutput(output) {
            session.addOutput(output)
            frameTapOutput = output
        }
        frameTap = tap
        return tap
    }

    private func ensureFrameTap() -> CameraFirstFrameTap {
        if let frameTapOutput, let frameTap, session.outputs.contains(frameTapOutput) {
            return frameTap
        }
        session.beginConfiguration()
        let tap = addFirstFrameTap()
        session.commitConfiguration()
        return tap
    }

    private func removeFrameTapOutput() {
        guard let output = frameTapOutput else { return }
        session.beginConfiguration()
        session.removeOutput(output)
        session.commitConfiguration()
        frameTapOutput = nil
        frameTap = nil
    }

    private func resolveCamera() -> AVCaptureDevice? {
        for attempt in 0..<Self.deviceAcquisitionAttempts {
            if let camera = discoverCamera() {
                return camera
            }
            if attempt < Self.deviceAcquisitionAttempts - 1 {
                Thread.sleep(forTimeInterval: Self.deviceRetryDelay)
            }
        }
        logger.error("No camera device found after \(Self.deviceAcquisitionAttempts) attempts")
        return nil
    }

    private func discoverCamera() -> AVCaptureDevice? {
        if let camera = AVCaptureDevice.default(for: .video) {
            return camera
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        return discovery.devices.first
    }

    // MARK: - Runtime errors

    private func observeRuntimeErrors() {
        guard runtimeErrorTask == nil else { return }
        let errors = NotificationCenter.default.notifications(
            named: AVCaptureSession.runtimeErrorNotification
        ).map { String(describing: $0.userInfo?[AVCaptureSessionErrorKey]) }

        runtimeErrorTask = Task { [weak self] in
            for await description in errors {
                await self?.handleRuntimeError(description)
            }
        }
    }

    private func handleRuntimeError(_ description: String) {
        logger.error("Camera session runtime error: \(description)")
        if session.isRunning {
            session.stopRunning()
        }
        isConfigured = false
        failureHandler?(.cameraUnavailable)
    }

    isolated deinit {
        runtimeErrorTask?.cancel()
    }
}
