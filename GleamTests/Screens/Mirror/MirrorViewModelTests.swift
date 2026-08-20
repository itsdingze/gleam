import CoreGraphics
import Testing
@testable import Gleam

struct MirrorViewModelTests {
    private let layout = MirrorLayout(
        screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 900),
        notchSize: CGSize(width: 180, height: 32)
    )

    @Test func enteringTheNotchExpandsImmediatelyWhileCaptureStarts() async {
        let camera = MockCameraCaptureService()
        await camera.holdStart()
        let viewModel = makeViewModel(camera: camera)

        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)

        #expect(viewModel.presentation == .expanded)
        #expect(viewModel.captureState == .starting)

        await camera.releaseStart()
        await waitUntil { viewModel.captureState == .running }
        #expect(viewModel.captureState == .running)
        let startCount = await camera.startCount
        #expect(startCount == 1)
    }

    @Test func collapsingStopsCapture() async {
        let camera = MockCameraCaptureService()
        let viewModel = makeViewModel(camera: camera)
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)

        await viewModel.collapseImmediately()

        let stopCount = await camera.stopCount
        #expect(viewModel.presentation == .collapsed)
        #expect(stopCount == 1)
    }

    @Test func collapsingKeepsTheFeedAliveThroughTheExitAnimation() async {
        let camera = MockCameraCaptureService()
        let clock = StepClockService()
        let viewModel = MirrorViewModel(
            appState: AppState(onboardingStep: nil, cameraPermission: .authorized),
            capture: camera,
            clock: clock
        )
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await waitUntil { viewModel.captureState == .running }

        viewModel.updatePointer(CGPoint(x: 950, y: 400), layout: layout)
        await clock.advance()
        await waitUntil { viewModel.presentation == .collapsed }

        #expect(viewModel.presentation == .collapsed)
        #expect(viewModel.captureState == .running)

        await clock.advance()
        await waitUntil { viewModel.captureState == .idle }
        #expect(viewModel.captureState == .idle)
        await waitUntil { await camera.stopCount == 1 }
        let stopCount = await camera.stopCount
        #expect(stopCount == 1)
    }

    @Test func reenteringDuringTheExitGraceKeepsCaptureRunning() async {
        let camera = MockCameraCaptureService()
        let clock = StepClockService()
        let viewModel = MirrorViewModel(
            appState: AppState(onboardingStep: nil, cameraPermission: .authorized),
            capture: camera,
            clock: clock
        )
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await waitUntil { viewModel.captureState == .running }
        viewModel.updatePointer(CGPoint(x: 950, y: 400), layout: layout)
        await clock.advance()
        await waitUntil { viewModel.presentation == .collapsed }

        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await yieldRepeatedly(times: 10)

        #expect(viewModel.presentation == .expanded)
        #expect(viewModel.captureState == .running)
        let stopCount = await camera.stopCount
        #expect(stopCount == 0)
    }

    @Test func finishingOnboardingCollapsesAndBlocksReExpansion() {
        let viewModel = makeViewModel(camera: MockCameraCaptureService())
        viewModel.showOnboarding()
        #expect(viewModel.presentation == .expanded)

        viewModel.finishOnboarding()
        #expect(viewModel.presentation == .collapsed)

        viewModel.showOnboarding()
        #expect(viewModel.presentation == .collapsed)
    }

    @Test func theWelcomePeekExpandsThenCollapsesOnItsOwn() async {
        let viewModel = makeViewModel(camera: MockCameraCaptureService())

        viewModel.playWelcomePeek()
        #expect(viewModel.presentation == .peek)

        await waitUntil { viewModel.presentation == .collapsed }
        #expect(viewModel.presentation == .collapsed)
        #expect(viewModel.captureState == .idle)
    }

    @Test func enteringTheNotchDuringThePeekCollapsesFirstThenOpensTheMirror() async {
        let viewModel = makeViewModel(camera: MockCameraCaptureService())
        viewModel.playWelcomePeek()

        viewModel.updatePointer(CGPoint(x: 500, y: 890), layout: layout)

        #expect(viewModel.presentation == .collapsed)

        await waitUntil { viewModel.presentation == .expanded }
        #expect(viewModel.presentation == .expanded)
        await waitUntil { viewModel.captureState == .running }
        #expect(viewModel.captureState == .running)
    }

    @Test func leavingDuringThePeekHandoffCancelsTheOpen() async {
        let viewModel = makeViewModel(camera: MockCameraCaptureService())
        viewModel.playWelcomePeek()

        viewModel.updatePointer(CGPoint(x: 500, y: 890), layout: layout)
        viewModel.updatePointer(CGPoint(x: 950, y: 400), layout: layout)
        await yieldRepeatedly(times: 10)

        #expect(viewModel.presentation == .collapsed)
        #expect(viewModel.captureState == .idle)
    }

    @Test func aFailedStartSurfacesTheError() async {
        let camera = MockCameraCaptureService()
        await camera.setStartError(CameraCaptureError.cameraUnavailable)
        let viewModel = makeViewModel(camera: camera)

        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)

        await waitUntil { viewModel.captureState == .failed(.cameraUnavailable) }
        #expect(viewModel.captureState == .failed(.cameraUnavailable))
        #expect(viewModel.previewLayer == nil)
        #expect(viewModel.presentation == .expanded)
    }

    @Test func leavingTheExpandedHoverRegionCollapsesAfterTheGracePeriod() async {
        let camera = MockCameraCaptureService()
        let viewModel = makeViewModel(camera: camera)
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)

        viewModel.updatePointer(CGPoint(x: 950, y: 400), layout: layout)
        await waitUntil { viewModel.presentation == .collapsed }

        #expect(viewModel.presentation == .collapsed)
    }

    @Test func enteringWhileACollapseIsPendingCanScheduleANewCollapse() async {
        let camera = MockCameraCaptureService()
        let clock = WaitingClockService()
        let viewModel = MirrorViewModel(
            appState: AppState(onboardingStep: nil, cameraPermission: .authorized),
            capture: camera,
            clock: clock
        )

        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        viewModel.updatePointer(CGPoint(x: 950, y: 400), layout: layout)
        await yieldRepeatedly(times: 10)
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        viewModel.updatePointer(CGPoint(x: 950, y: 400), layout: layout)
        await yieldRepeatedly(times: 10)

        let sleepCount = await clock.sleepCount
        #expect(sleepCount == 2)
        #expect(viewModel.presentation == .expanded)
    }

    @Test func pointerMovementWhilePausedCollapsesAndStopsCapture() async {
        let camera = MockCameraCaptureService()
        let appState = AppState(onboardingStep: nil, cameraPermission: .authorized)
        let viewModel = MirrorViewModel(
            appState: appState,
            capture: camera,
            clock: ImmediateClockService()
        )
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await waitUntil { viewModel.captureState == .running }

        appState.isPaused = true
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)

        #expect(viewModel.presentation == .collapsed)
        await waitUntil { viewModel.captureState == .idle }
        #expect(viewModel.captureState == .idle)
        await waitUntil { await camera.stopCount >= 1 }
        let stopCount = await camera.stopCount
        #expect(stopCount >= 1)
    }

    @Test func aMidSessionFailureSurfacesWhileTheMirrorIsOpen() async {
        let camera = MockCameraCaptureService()
        let viewModel = makeViewModel(camera: camera)
        viewModel.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await waitUntil { viewModel.captureState == .running }

        await camera.failMidSession(.cameraUnavailable)

        await waitUntil { viewModel.captureState == .failed(.cameraUnavailable) }
        #expect(viewModel.captureState == .failed(.cameraUnavailable))
        #expect(viewModel.previewLayer == nil)
        await waitUntil { await camera.stopCount >= 1 }
        let stopCount = await camera.stopCount
        #expect(stopCount >= 1)
    }

    private func makeViewModel(camera: MockCameraCaptureService) -> MirrorViewModel {
        MirrorViewModel(
            appState: AppState(onboardingStep: nil, cameraPermission: .authorized),
            capture: camera,
            clock: ImmediateClockService()
        )
    }

}

private actor WaitingClockService: ClockService {
    private(set) var sleepCount = 0

    func sleep(for duration: Duration) async throws {
        sleepCount += 1
        try await Task.sleep(for: .seconds(60))
    }
}

