@testable import Gleam

@MainActor
final class MockLoginItemService: LoginItemService {
    private(set) var enabled: Bool
    private(set) var setEnabledCallCount = 0
    private let failure: (any Error)?

    init(enabled: Bool = false, failure: (any Error)? = nil) {
        self.enabled = enabled
        self.failure = failure
    }

    func changeOutsideTheApp(to enabled: Bool) {
        self.enabled = enabled
    }

    func isEnabled() -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        setEnabledCallCount += 1
        if let failure { throw failure }
        self.enabled = enabled
    }
}
