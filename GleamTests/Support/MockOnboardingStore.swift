@testable import Gleam

@MainActor
final class MockOnboardingStore: OnboardingStore {
    private(set) var isCompleted: Bool

    init(isCompleted: Bool = false) {
        self.isCompleted = isCompleted
    }

    func hasCompletedOnboarding() -> Bool {
        isCompleted
    }

    func markOnboardingCompleted() {
        isCompleted = true
    }
}
