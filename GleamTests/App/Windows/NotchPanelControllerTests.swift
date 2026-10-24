import AppKit
import Testing
@testable import Gleam

struct NotchPanelControllerTests {
    private let layout = MirrorLayout(
        screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 900),
        notchSize: CGSize(width: 180, height: 32)
    )

    @Test func theMirrorReturnsAfterTheNotchedScreenComesBack() async {
        let locator = MockNotchScreenLocator(layout: layout)
        let harness = makeHarness(locator: locator)

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }

        locator.layout = nil
        harness.screenParametersChanged()
        await waitUntil { harness.controller.isMirrorVisible == false }
        #expect(harness.controller.isMirrorVisible == false)

        locator.layout = layout
        harness.screenParametersChanged()
        await waitUntil { harness.controller.isMirrorVisible }
        #expect(harness.controller.isMirrorVisible)

        harness.controller.stop()
    }

    @Test func losingTheNotchedScreenStopsCapture() async {
        let camera = MockCameraCaptureService()
        let locator = MockNotchScreenLocator(layout: layout)
        let harness = makeHarness(locator: locator, camera: camera)
        let mirror = harness.container.mirrorViewModel

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }
        mirror.updatePointer(CGPoint(x: 500, y: 880), layout: layout)
        await waitUntil { mirror.captureState == .running }

        locator.layout = nil
        harness.screenParametersChanged()

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
        let harness = makeHarness(locator: locator)

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }
        #expect(harness.controller.mirrorFrame == layout.panelFrame)

        let rescaled = MirrorLayout(
            screenFrame: CGRect(x: 0, y: 0, width: 1_400, height: 1_200),
            notchSize: CGSize(width: 200, height: 38)
        )
        let windowBefore = harness.controller.mirrorWindowNumber

        locator.layout = rescaled
        harness.screenParametersChanged()
        await waitUntil { harness.controller.mirrorFrame == rescaled.panelFrame }

        #expect(harness.controller.mirrorFrame == rescaled.panelFrame)
        #expect(harness.controller.isMirrorVisible)
        #expect(harness.controller.mirrorWindowNumber == windowBefore)

        harness.controller.stop()
    }

    @Test func finishingOnboardingDropsThePanelToTheOverlayLevelWithoutPointerMovement() async {
        let state = AppState(onboardingStep: .permission, cameraPermission: .authorized)
        let harness = makeHarness(
            locator: MockNotchScreenLocator(layout: layout),
            state: state,
            store: MockOnboardingStore(isCompleted: false)
        )

        harness.controller.start()
        await waitUntil { harness.controller.mirrorLevel == .floating }

        state.onboardingStep = nil

        await waitUntil { harness.controller.mirrorLevel == .screenSaver }
        #expect(harness.controller.mirrorLevel == .screenSaver)

        harness.controller.stop()
    }

    @Test func nothingWakesPeriodicallyWhilePermissionIsGranted() async {
        let harness = makeHarness(locator: MockNotchScreenLocator(layout: layout))

        harness.controller.start()
        await waitUntil { harness.controller.isMirrorVisible }
        await yieldRepeatedly()

        #expect(await harness.clock.pendingSleeperCount == 0)

        harness.controller.stop()
    }

    @Test func aCameraGrantMadeInSystemSettingsIsPickedUpThenChecksStop() async {
        let state = AppState(onboardingStep: nil, cameraPermission: .denied)
        let permission = MockCameraPermissionService(permission: .denied)
        let harness = makeHarness(
            locator: MockNotchScreenLocator(layout: layout),
            state: state,
            permission: permission
        )

        harness.controller.start()
        await waitUntil { await harness.clock.pendingSleeperCount == 1 }

        await permission.change(to: .authorized)
        await harness.clock.advance()

        await waitUntil { state.cameraPermission == .authorized }
        #expect(state.cameraPermission == .authorized)
        await waitUntil { await harness.clock.pendingSleeperCount == 0 }
        #expect(await harness.clock.pendingSleeperCount == 0)

        harness.controller.stop()
    }

    @Test func aGrantDuringOnboardingStillRidesOutTheCollapse() async {
        let state = AppState(onboardingStep: .permission, cameraPermission: .denied)
        let permission = MockCameraPermissionService(permission: .denied)
        let harness = makeHarness(
            locator: MockNotchScreenLocator(layout: layout),
            state: state,
            permission: permission,
            store: MockOnboardingStore(isCompleted: false)
        )

        harness.controller.start()
        await waitUntil { await harness.clock.pendingSleeperCount == 2 }
        await harness.clock.advance()
        await permission.change(to: .authorized)
        await harness.clock.advance()
        await waitUntil { state.cameraPermission == .authorized }
        await yieldRepeatedly()

        #expect(state.onboardingStep == .permission)

        await harness.clock.advance()
        await waitUntil { state.onboardingStep == nil }
        #expect(state.onboardingStep == nil)

        harness.controller.stop()
    }

    @Test func anAlreadyAuthorizedUserOnThePermissionStepFinishesOnboarding() async {
        let state = AppState(onboardingStep: .permission, cameraPermission: .authorized)
        let harness = makeHarness(
            locator: MockNotchScreenLocator(layout: layout),
            state: state,
            store: MockOnboardingStore(isCompleted: false)
        )

        harness.controller.start()
        await waitUntil { await harness.clock.pendingSleeperCount == 2 }
        await harness.clock.advance()
        await harness.clock.advance()
        await harness.clock.advance()

        await waitUntil { state.onboardingStep == nil }
        #expect(state.onboardingStep == nil)

        harness.controller.stop()
    }

    private struct Harness {
        let container: DependencyContainer
        let controller: NotchPanelController
        let clock: StepClockService
        let notificationCenter: NotificationCenter

        func screenParametersChanged() {
            notificationCenter.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        }
    }

    private func makeHarness(
        locator: MockNotchScreenLocator,
        state: AppState = AppState(onboardingStep: nil, cameraPermission: .authorized),
        permission: MockCameraPermissionService = MockCameraPermissionService(permission: .authorized),
        store: MockOnboardingStore = MockOnboardingStore(isCompleted: true),
        camera: MockCameraCaptureService = MockCameraCaptureService()
    ) -> Harness {
        let clock = StepClockService()
        let notificationCenter = NotificationCenter()
        let container = DependencyContainer(
            appState: state,
            permissionService: permission,
            onboardingStore: store,
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
                notificationCenter: notificationCenter,
                tracksPointer: false
            ),
            clock: clock,
            notificationCenter: notificationCenter
        )
    }
}
