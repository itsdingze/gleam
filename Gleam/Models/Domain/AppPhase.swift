enum AppPhase: Equatable, Sendable {
    case onboarding(OnboardingStep)
    case active
    case paused
    case unavailable
}
