import Foundation

@MainActor
final class UserDefaultsOnboardingStore: OnboardingStore {
    private let defaults: UserDefaults
    private let completionKey: String

    init(
        defaults: UserDefaults = .standard,
        completionKey: String = "hasCompletedOnboarding"
    ) {
        self.defaults = defaults
        self.completionKey = completionKey
    }

    func hasCompletedOnboarding() -> Bool {
        defaults.bool(forKey: completionKey)
    }

    func markOnboardingCompleted() {
        defaults.set(true, forKey: completionKey)
    }
}
