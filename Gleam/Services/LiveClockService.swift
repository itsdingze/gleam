import Foundation

struct LiveClockService: ClockService {
    private let clock = ContinuousClock()

    nonisolated init() {}

    func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}
