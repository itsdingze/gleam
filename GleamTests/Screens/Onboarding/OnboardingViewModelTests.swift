import Testing
@testable import Gleam

struct OnboardingViewModelTests {
    @Test func nextMovesThroughWelcomeAndInstructions() {
        let state = AppState(onboardingStep: .welcome)
        let viewModel = makeViewModel(state: state, mirror: makeMirror(state: state))

        viewModel.next()
        #expect(viewModel.step == .instructions)

        viewModel.next()
        #expect(viewModel.step == .permission)
    }

    @Test func grantingPermissionCollapsesTheMirrorThenClearsTheStep() async {
        let state = AppState(onboardingStep: .permission)
        let mirror = makeMirror(state: state)
        mirror.showOnboarding()
        let viewModel = makeViewModel(state: state, permission: .authorized, mirror: mirror)

        await viewModel.requestCameraPermission()

        #expect(state.onboardingStep == nil)
        await waitUntil { mirror.presentation == .collapsed }
        #expect(mirror.presentation == .collapsed)
    }

    @Test func onboardingStaysVisibleUntilTheRideOutEnds() async {
        let state = AppState(onboardingStep: .permission)
        let clock = HoldingClockService()
        let mirror = makeMirror(state: state)
        mirror.showOnboarding()
        let viewModel = makeViewModel(state: state, permission: .authorized, mirror: mirror, clock: clock)

        let request = Task { await viewModel.requestCameraPermission() }
        await waitUntil { mirror.presentation == .collapsed }

        #expect(state.onboardingStep == .permission)

        await clock.releaseAll()
        await request.value
        #expect(state.onboardingStep == nil)
    }

    @Test func finishingOnboardingPlaysTheWelcomePeek() async {
        let state = AppState(onboardingStep: .permission)
        let mirror = MirrorViewModel(
            appState: state,
            capture: MockCameraCaptureService(),
            clock: HoldingClockService()
        )
        mirror.showOnboarding()
        let viewModel = makeViewModel(state: state, permission: .authorized, mirror: mirror)

        await viewModel.requestCameraPermission()

        #expect(mirror.presentation == .peek)
    }

    @Test func aReturningAuthorizedUserSkipsOnboarding() async {
        let state = AppState()
        let viewModel = makeViewModel(
            state: state,
            permission: .authorized,
            mirror: makeMirror(state: state),
            store: MockOnboardingStore(isCompleted: true)
        )

        await viewModel.prepare()

        #expect(state.onboardingStep == nil)
    }

    @Test func aReturningUserWithoutPermissionStillSeesOnboarding() async {
        let state = AppState()
        let viewModel = makeViewModel(
            state: state,
            permission: .denied,
            mirror: makeMirror(state: state),
            store: MockOnboardingStore(isCompleted: true)
        )

        await viewModel.prepare()

        #expect(state.onboardingStep == .welcome)
        #expect(state.cameraPermission == .denied)
    }

    @Test func aFirstRunUserSeesOnboardingEvenWhenAlreadyAuthorized() async {
        let state = AppState()
        let viewModel = makeViewModel(
            state: state,
            permission: .authorized,
            mirror: makeMirror(state: state),
            store: MockOnboardingStore(isCompleted: false)
        )

        await viewModel.prepare()

        #expect(state.onboardingStep == .welcome)
    }

    @Test func aDeniedPermissionRequestLeavesOnboardingOnThePermissionStep() async {
        let state = AppState(onboardingStep: .permission)
        let viewModel = makeViewModel(
            state: state,
            permission: .denied,
            mirror: makeMirror(state: state)
        )

        await viewModel.requestCameraPermission()

        #expect(state.onboardingStep == .permission)
        #expect(state.cameraPermission == .denied)
        #expect(viewModel.isRequestingPermission == false)
    }

    private func makeMirror(state: AppState) -> MirrorViewModel {
        MirrorViewModel(
            appState: state,
            capture: MockCameraCaptureService(),
            clock: ImmediateClockService()
        )
    }

    private func makeViewModel(
        state: AppState,
        permission: CameraPermission = .notDetermined,
        mirror: MirrorViewModel,
        store: MockOnboardingStore = MockOnboardingStore(),
        clock: any ClockService = ImmediateClockService()
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            appState: state,
            permission: MockCameraPermissionService(permission: permission),
            store: store,
            mirrorViewModel: mirror,
            clock: clock
        )
    }

}

private actor HoldingClockService: ClockService {
    private var sleepers: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws {
        await withCheckedContinuation { sleepers.append($0) }
    }

    func releaseAll() {
        while sleepers.isEmpty == false {
            sleepers.removeFirst().resume()
        }
    }
}
