@MainActor
protocol OnboardingStore: AnyObject {
    func hasCompletedOnboarding() -> Bool
    func markOnboardingCompleted()
}
