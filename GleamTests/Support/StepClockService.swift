import Testing
@testable import Gleam

actor StepClockService: ClockService {
    private var sleepers: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws {
        await withCheckedContinuation { sleepers.append($0) }
    }

    nonisolated func advance(
        attempts: Int = 500,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async {
        for _ in 0..<attempts {
            if await resumeNextSleeper() {
                await Task.yield()
                return
            }
            await Task.yield()
        }
        Issue.record("No sleeper to advance after \(attempts) yields", sourceLocation: sourceLocation)
    }

    private func resumeNextSleeper() -> Bool {
        guard sleepers.isEmpty == false else { return false }
        sleepers.removeFirst().resume()
        return true
    }
}
