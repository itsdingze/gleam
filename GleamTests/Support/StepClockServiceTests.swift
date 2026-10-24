import Testing
@testable import Gleam

struct StepClockServiceTests {
    @Test(.timeLimit(.minutes(1)))
    func cancellingASleeperEndsItsSleepWithCancellation() async {
        let clock = StepClockService()
        let sleeper = Task { try await clock.sleep(for: .seconds(1)) }
        await waitUntil { await clock.pendingSleeperCount == 1 }

        sleeper.cancel()

        let result = await sleeper.result
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(await clock.pendingSleeperCount == 0)
    }

    @Test func anImmediateSleepInACancelledTaskThrowsCancellation() async {
        let sleeper = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            try await ImmediateClockService().sleep(for: .seconds(1))
        }

        let result = await sleeper.result

        #expect(throws: CancellationError.self) { try result.get() }
    }
}
