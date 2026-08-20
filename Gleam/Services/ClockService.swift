import Foundation

protocol ClockService: Sendable {
    func sleep(for duration: Duration) async throws
}
