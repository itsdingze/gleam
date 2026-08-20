import CoreGraphics
import Testing
@testable import Gleam

struct NotchPanelControllerTests {
    private let layout = MirrorLayout(
        screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 900),
        notchSize: CGSize(width: 180, height: 32)
    )

    @Test func theMirrorReturnsAfterTheNotchedScreenComesBack() async {
        let locator = MockNotchScreenLocator(layout: layout)
        let clock = StepClockService()
        let harness = makeHarness(locator: locator, clock: clock)

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }

        locator.layout = nil
        await clock.advance()
        await waitUntil { harness.controller.isMirrorVisible == false }
        #expect(harness.controller.isMirrorVisible == false)

        locator.layout = layout
        await clock.advance()
        await waitUntil { harness.controller.isMirrorVisible }
        #expect(harness.controller.isMirrorVisible)

        harness.controller.stop()
    }

    @Test func losingTheNotchedScreenStopsCapture() async {
        let camera = MockCameraCaptureService()
        let locator = MockNotchScreenLocator(layout: layout)
        let clock = StepClockService()
        let harness = makeHarness(locator: locator, clock: clock, camera: camera)
        let mirror = harness.container.mirrorViewModel

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }
        mirror.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await waitUntil { mirror.captureState == .running }

        locator.layout = nil
        await clock.advance()

        await waitUntil { mirror.presentation == .collapsed }
        await waitUntil { mirror.captureState == .idle }
        #expect(mirror.presentation == .collapsed)
        #expect(mirror.captureState == .idle)
        await waitUntil { await camera.stopCount >= 1 }
        let stopCount = await camera.stopCount
        #expect(stopCount >= 1)

        harness.controller.stop()
    }

    @Test func aResolutionChangeMovesThePanelToTheNewLayout() async {
        let locator = MockNotchScreenLocator(layout: layout)
        let clock = StepClockService()
        let harness = makeHarness(locator: locator, clock: clock)

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }
        #expect(harness.controller.mirrorFrame == layout.panelFrame)

        let rescaled = MirrorLayout(
            screenFrame: CGRect(x: 0, y: 0, width: 1_400, height: 1_200),
            notchSize: CGSize(width: 200, height: 38)
        )
        let windowBefore = harness.controller.mirrorWindowNumber

        locator.layout = rescaled
        await clock.advance()
        await waitUntil { harness.controller.mirrorFrame == rescaled.panelFrame }

        #expect(harness.controller.mirrorFrame == rescaled.panelFrame)
        #expect(harness.controller.isMirrorVisible)
        #expect(harness.controller.mirrorWindowNumber == windowBefore)

        harness.controller.stop()
    }

    private struct Harness {
        let container: DependencyContainer
        let controller: NotchPanelController
    }

    private func makeHarness(
        locator: MockNotchScreenLocator,
        clock: any ClockService,
        camera: MockCameraCaptureService = MockCameraCaptureService()
    ) -> Harness {
        let container = DependencyContainer(
            appState: AppState(onboardingStep: nil, cameraPermission: .authorized),
            permissionService: MockCameraPermissionService(permission: .authorized),
            onboardingStore: MockOnboardingStore(isCompleted: true),
            cameraService: camera,
            clock: clock,
            updateService: MockUpdateService(),
            loginItemService: MockLoginItemService()
        )
        return Harness(
            container: container,
            controller: NotchPanelController(
                appState: container.appState,
                mirrorViewModel: container.mirrorViewModel,
                onboardingViewModel: container.onboardingViewModel,
                screenLocator: locator,
                clock: clock,
                tracksPointer: false
            )
        )
    }

}
