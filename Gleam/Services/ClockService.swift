import Foundation

nonisolated protocol ClockService: Sendable {
    func sleep(for duration: Duration) async throws
}
