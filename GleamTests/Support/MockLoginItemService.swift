@testable import Gleam

@MainActor
final class MockLoginItemService: LoginItemService {
    private(set) var enabled: Bool
    private let failure: (any Error)?

    init(enabled: Bool = false, failure: (any Error)? = nil) {
        self.enabled = enabled
        self.failure = failure
    }

    func isEnabled() -> Bool {
        enabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if let failure { throw failure }
        self.enabled = enabled
    }
}
