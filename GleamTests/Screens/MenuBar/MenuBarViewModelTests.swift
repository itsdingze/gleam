import CoreGraphics
import Testing
@testable import Gleam

struct MenuBarViewModelTests {
    @Test func launchAtStartupReflectsLoginItemState() {
        let loginItem = MockLoginItemService(enabled: true)
        let viewModel = makeViewModel(loginItem: loginItem)

        #expect(viewModel.launchAtStartup == true)
    }

    @Test func togglingLaunchAtStartupUpdatesLoginItem() {
        let loginItem = MockLoginItemService(enabled: false)
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.launchAtStartup = true
        #expect(loginItem.enabled == true)

        viewModel.launchAtStartup = false
        #expect(loginItem.enabled == false)
    }

    @Test func aRejectedRegistrationSnapsTheSwitchBackOff() {
        let loginItem = MockLoginItemService(enabled: false, failure: LoginItemFailure())
        let viewModel = makeViewModel(loginItem: loginItem)

        viewModel.launchAtStartup = true

        #expect(viewModel.launchAtStartup == false)
        #expect(loginItem.enabled == false)
    }

    @Test func autoUpdateReflectsTheUpdateServiceState() {
        let updates = MockUpdateService(automaticChecksEnabled: false)
        let viewModel = makeViewModel(updates: updates)

        #expect(viewModel.autoUpdateEnabled == false)
    }

    @Test func togglingAutoUpdateUpdatesTheUpdateService() {
        let updates = MockUpdateService(automaticChecksEnabled: false)
        let viewModel = makeViewModel(updates: updates)

        viewModel.autoUpdateEnabled = true
        #expect(updates.automaticChecksEnabled == true)

        viewModel.autoUpdateEnabled = false
        #expect(updates.automaticChecksEnabled == false)
    }

    @Test func actionUsesAccentOnlyWhenResuming() {
        let state = AppState()
        let viewModel = makeViewModel(state: state)

        state.isPaused = true
        #expect(viewModel.actionIsResume == true)

        state.isPaused = false
        #expect(viewModel.actionIsResume == false)
    }

    @Test func pausingStopsCapture() async {
        let camera = MockCameraCaptureService()
        let state = AppState(onboardingStep: nil, cameraPermission: .authorized)
        let mirror = MirrorViewModel(
            appState: state,
            capture: camera,
            clock: ImmediateClockService()
        )
        let viewModel = makeViewModel(state: state, mirror: mirror)
        mirror.updatePointer(
            CGPoint(x: 500, y: 880),
            layout: MirrorLayout(
                screenFrame: CGRect(x: 0, y: 0, width: 1_000, height: 900),
                notchSize: CGSize(width: 180, height: 32)
            )
        )
        await waitUntil { mirror.captureState == .running }

        viewModel.togglePause()

        await waitUntil { mirror.captureState == .idle }
        #expect(mirror.captureState == .idle)
        #expect(mirror.presentation == .collapsed)
        await waitUntil { await camera.stopCount >= 1 }
        let stopCount = await camera.stopCount
        #expect(stopCount >= 1)
    }

    private func makeViewModel(
        state: AppState = AppState(),
        loginItem: MockLoginItemService = MockLoginItemService(),
        updates: MockUpdateService = MockUpdateService(),
        mirror: MirrorViewModel? = nil
    ) -> MenuBarViewModel {
        MenuBarViewModel(
            appState: state,
            permission: MockCameraPermissionService(permission: .authorized),
            loginItem: loginItem,
            updates: updates,
            mirror: mirror ?? MirrorViewModel(
                appState: state,
                capture: MockCameraCaptureService(),
                clock: ImmediateClockService()
            )
        )
    }

}

private struct LoginItemFailure: Error {}
