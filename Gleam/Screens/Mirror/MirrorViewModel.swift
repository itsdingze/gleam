import AVFoundation
import Observation

@MainActor
@Observable
final class MirrorViewModel {
    private static let collapseDelay = Duration.milliseconds(250)
    private static let exitFeedGrace = Duration.milliseconds(400)
    private static let peekHold = Duration.milliseconds(2_000)
    private static let peekHandoffPause = Duration.milliseconds(450)

    private let appState: AppState
    private let session: CameraSessionController
    private let clock: any ClockService

    private var collapseTask: Task<Void, Never>?
    private var collapseGeneration = 0
    private var exitGraceTask: Task<Void, Never>?
    private var exitGraceGeneration = 0
    private var hasFinishedOnboarding = false
    private var peekTask: Task<Void, Never>?
    private var peekHandoffTask: Task<Void, Never>?

    private(set) var presentation: MirrorPresentation = .collapsed
    private(set) var isWelcomePeekContentActive = false

    init(
        appState: AppState,
        capture: any CameraCaptureService,
        clock: any ClockService,
        logger: any LoggerService = OSLogLoggerService(category: "mirror")
    ) {
        self.appState = appState
        self.session = CameraSessionController(capture: capture, logger: logger)
        self.clock = clock
    }

    var isExpanded: Bool {
        presentation == .expanded
    }

    var captureState: CaptureState {
        session.state
    }

    var previewLayer: AVCaptureVideoPreviewLayer? {
        session.previewLayer
    }

    func showOnboarding() {
        guard hasFinishedOnboarding == false else { return }
        cancelScheduledCollapse()
        presentation = .expanded
    }

    func updatePointer(_ point: CGPoint, layout: MirrorLayout) {
        guard appState.isOperational else {
            performCollapse()
            cancelExitGrace()
            session.stopIfNeeded()
            return
        }

        session.prepareIfNeeded()

        let hoverFrame = layout.hoverFrame(for: presentation)
        if hoverFrame.contains(point) {
            cancelScheduledCollapse()
            if presentation == .peek {
                beginPeekHandoff()
            } else if peekHandoffTask == nil {
                expand()
            }
        } else if presentation == .expanded {
            scheduleCollapse()
        } else if peekHandoffTask != nil {
            cancelPeekHandoff()
        }
    }

    private func beginPeekHandoff() {
        peekTask?.cancel()
        peekTask = nil
        presentation = .collapsed
        peekHandoffTask = Task { [weak self, clock] in
            try? await clock.sleep(for: Self.peekHandoffPause)
            guard Task.isCancelled == false else { return }
            guard let self else { return }
            self.peekHandoffTask = nil
            self.expand()
        }
    }

    private func cancelPeekHandoff() {
        peekHandoffTask?.cancel()
        peekHandoffTask = nil
    }

    func finishOnboarding() {
        hasFinishedOnboarding = true
        performCollapse()
    }

    func playWelcomePeek() {
        guard presentation == .collapsed else { return }
        presentation = .peek
        isWelcomePeekContentActive = true
        peekTask = Task { [weak self, clock] in
            try? await clock.sleep(for: Self.peekHold)
            guard Task.isCancelled == false else { return }
            guard let self, self.presentation == .peek else { return }
            self.peekTask = nil
            self.presentation = .collapsed
        }
    }

    func collapseImmediately() async {
        performCollapse()
        cancelExitGrace()
        session.stopIfNeeded()
        await session.waitForPendingWork()
    }

    // MARK: - Presentation

    private func expand() {
        guard presentation != .expanded else { return }
        cancelExitGrace()
        isWelcomePeekContentActive = false
        presentation = .expanded
        session.startIfIdle()
    }

    private func performCollapse() {
        cancelScheduledCollapse()
        peekTask?.cancel()
        peekTask = nil
        cancelPeekHandoff()
        guard presentation != .collapsed else { return }
        presentation = .collapsed
        scheduleExitGrace()
    }

    private func scheduleExitGrace() {
        cancelExitGrace()
        exitGraceGeneration += 1
        let generation = exitGraceGeneration
        exitGraceTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.exitFeedGrace)
            } catch {
                return
            }
            guard Task.isCancelled == false else { return }
            guard let self, self.exitGraceGeneration == generation else { return }
            self.exitGraceTask = nil
            self.session.stopIfNeeded()
        }
    }

    private func cancelExitGrace() {
        exitGraceGeneration += 1
        exitGraceTask?.cancel()
        exitGraceTask = nil
    }

    // MARK: - Scheduled collapse

    private func scheduleCollapse() {
        guard collapseTask == nil else { return }
        collapseGeneration += 1
        let generation = collapseGeneration
        collapseTask = Task { [weak self, clock] in
            do {
                try await clock.sleep(for: Self.collapseDelay)
                guard Task.isCancelled == false else { return }
                self?.clearScheduledCollapse(generation: generation)
                self?.performCollapse()
            } catch {
                self?.clearScheduledCollapse(generation: generation)
                return
            }
        }
    }

    private func cancelScheduledCollapse() {
        collapseGeneration += 1
        collapseTask?.cancel()
        collapseTask = nil
    }

    private func clearScheduledCollapse(generation: Int) {
        guard collapseGeneration == generation else { return }
        collapseTask = nil
    }

    isolated deinit {
        collapseTask?.cancel()
        exitGraceTask?.cancel()
        peekTask?.cancel()
        peekHandoffTask?.cancel()
    }
}
