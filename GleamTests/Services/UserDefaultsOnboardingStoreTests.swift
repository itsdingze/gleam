import Foundation
import Testing
@testable import Gleam

struct UserDefaultsOnboardingStoreTests {
    @Test func aFreshInstallHasNotCompletedOnboarding() {
        withScratchKey("fresh-install") { defaults, key in
            let store = UserDefaultsOnboardingStore(defaults: defaults, completionKey: key)

            #expect(store.hasCompletedOnboarding() == false)
        }
    }

    @Test func completionSurvivesANewStoreOverTheSameDefaults() {
        withScratchKey("completion-persists") { defaults, key in
            UserDefaultsOnboardingStore(defaults: defaults, completionKey: key).markOnboardingCompleted()

            #expect(UserDefaultsOnboardingStore(defaults: defaults, completionKey: key).hasCompletedOnboarding())
        }
    }

    @Test func storesOnDifferentKeysDoNotSeeEachOther() {
        withScratchKey("independent-mine") { defaults, key in
            withScratchKey("independent-yours") { _, otherKey in
                UserDefaultsOnboardingStore(defaults: defaults, completionKey: key).markOnboardingCompleted()

                let other = UserDefaultsOnboardingStore(defaults: defaults, completionKey: otherKey)
                #expect(other.hasCompletedOnboarding() == false)
            }
        }
    }

    // The sandboxed test host cannot back a scratch UserDefaults suite, so tests namespace a key instead.
    private func withScratchKey(_ name: String, _ body: (UserDefaults, String) -> Void) {
        let defaults = UserDefaults.standard
        let key = "com.dingze.Gleam.tests.\(name)"
        defaults.removeObject(forKey: key)
        defer { defaults.removeObject(forKey: key) }
        body(defaults, key)
    }
}
