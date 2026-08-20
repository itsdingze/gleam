import Observation

@MainActor
@Observable
final class AppState {
    var onboardingStep: OnboardingStep?
    var cameraPermission: CameraPermission
    var isPaused = false

    init(
        onboardingStep: OnboardingStep? = .welcome,
        cameraPermission: CameraPermission = .notDetermined
    ) {
        self.onboardingStep = onboardingStep
        self.cameraPermission = cameraPermission
    }

    var phase: AppPhase {
        if let onboardingStep {
            return .onboarding(onboardingStep)
        }
        guard cameraPermission == .authorized else {
            return .unavailable
        }
        return isPaused ? .paused : .active
    }

    var isOperational: Bool {
        phase == .active
    }
}
