import Foundation
import Testing
@testable import Gleam

actor StepClockService: ClockService {
    private struct Sleeper {
        let id: UUID
        let continuation: CheckedContinuation<Void, any Error>
    }

    private var sleepers: [Sleeper] = []

    var pendingSleeperCount: Int {
        sleepers.count
    }

    func sleep(for duration: Duration) async throws {
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
                register(Sleeper(id: id, continuation: continuation))
            }
        } onCancel: {
            Task { await self.cancelSleeper(id) }
        }
    }

    private func register(_ sleeper: Sleeper) {
        guard Task.isCancelled == false else {
            sleeper.continuation.resume(throwing: CancellationError())
            return
        }
        sleepers.append(sleeper)
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

    func releaseAll() {
        while resumeNextSleeper() {}
    }

    private func resumeNextSleeper() -> Bool {
        guard sleepers.isEmpty == false else { return false }
        sleepers.removeFirst().continuation.resume()
        return true
    }

    private func cancelSleeper(_ id: UUID) {
        guard let index = sleepers.firstIndex(where: { $0.id == id }) else { return }
        sleepers.remove(at: index).continuation.resume(throwing: CancellationError())
    }
}
