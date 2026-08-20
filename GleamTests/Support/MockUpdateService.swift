@testable import Gleam

@MainActor
final class MockUpdateService: UpdateService {
    private(set) var automaticChecksEnabled: Bool
    private(set) var startCount = 0

    init(automaticChecksEnabled: Bool = true) {
        self.automaticChecksEnabled = automaticChecksEnabled
    }

    func isAutomaticCheckEnabled() -> Bool {
        automaticChecksEnabled
    }

    func setAutomaticCheckEnabled(_ enabled: Bool) {
        automaticChecksEnabled = enabled
    }

    func start() {
        startCount += 1
    }
}
