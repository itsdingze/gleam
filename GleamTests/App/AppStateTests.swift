import Testing
@testable import Gleam

struct AppStateTests {
    @Test func authorizedCompletedAppIsActive() {
        let state = AppState(onboardingStep: nil, cameraPermission: .authorized)

        #expect(state.phase == .active)
        #expect(state.isOperational)
    }

    @Test func pauseTurnsTheOperationalStateOff() {
        let state = AppState(onboardingStep: nil, cameraPermission: .authorized)
        state.isPaused = true

        #expect(state.phase == .paused)
        #expect(state.isOperational == false)
    }

    @Test func revokedCameraPermissionMakesTheAppUnavailable() {
        let state = AppState(onboardingStep: nil, cameraPermission: .denied)

        #expect(state.phase == .unavailable)
        #expect(state.isOperational == false)
    }
}
